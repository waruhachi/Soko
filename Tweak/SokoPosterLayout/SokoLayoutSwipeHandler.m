#import "SokoLayoutSwipeHandler.h"

static const CGFloat kSokoLayoutSwipeDistance = 30.0;
static const CGFloat kSokoLayoutSwipeVelocity = 300.0;
static const CGFloat kSokoLayoutSwipeSlop = 24.0;
static const NSTimeInterval kSokoLayoutSwipeMaximumHold = 0.3;

@interface SokoLayoutSwipeHandler ()
@property (nonatomic, weak) PREditingSceneViewController *editingSceneViewController;
@property (nonatomic, weak) UIViewController *complicationContainerViewController;
@property (nonatomic) NSTimeInterval touchTimestamp;
@property (nonatomic) CGFloat peakMovement;
- (void)installOnWindows;
@end

static NSHashTable<SokoLayoutSwipeHandler *> *gSwipeHandlers;
static SokoLayoutSwipeHandler *gLooseHandler;

static CGPoint SokoScreenPoint(UIView *view, CGPoint point) {
	UIScreen *screen = view.window.screen ?: ([view isKindOfClass:[UIWindow class]] ? ((UIWindow *)view).screen : nil);
	return screen ? [view convertPoint:point toCoordinateSpace:screen.coordinateSpace] : point;
}

// The row is rendered in another process's windows, so every window gets a pan scoped to the row by its start point.
static void SokoSwipeHandlersEnsure(void) {
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		gSwipeHandlers = [NSHashTable weakObjectsHashTable];
		for (NSNotificationName name in @[UIWindowDidBecomeKeyNotification, UIWindowDidBecomeVisibleNotification]) {
			[NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *notification) {
				for (SokoLayoutSwipeHandler *handler in gSwipeHandlers) [handler installOnWindows];
			}];
		}
	});
}

@implementation SokoLayoutSwipeHandler

+ (void)installOnEditingSceneViewController:(PREditingSceneViewController *)controller {
	SokoLayoutSwipeHandler *handler = objc_getAssociatedObject(controller, @selector(installOnEditingSceneViewController:));
	if (!handler) {
		handler = [self new];
		handler.editingSceneViewController = controller;
		objc_setAssociatedObject(controller, @selector(installOnEditingSceneViewController:), handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	[handler install];
}

+ (void)installOnComplicationContainerViewController:(UIViewController *)controller {
	if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.PosterBoard"]) return;

	SokoLayoutSwipeHandler *handler = objc_getAssociatedObject(controller, @selector(installOnComplicationContainerViewController:));
	if (!handler) {
		handler = [self new];
		handler.complicationContainerViewController = controller;
		objc_setAssociatedObject(controller, @selector(installOnComplicationContainerViewController:), handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	[handler install];
}

- (void)install {
	SokoSwipeHandlersEnsure();
	[gSwipeHandlers addObject:self];
	[self installOnWindows];
}

- (void)installOnWindows {
	for (UIWindow *window in UIApplication.sharedApplication.windows) {
		[self attachSwipeTo:window];
	}
}

+ (void)attachSwipesToAllWindows {
	BOOL hasHandlers = NO;
	for (SokoLayoutSwipeHandler *handler in gSwipeHandlers) {
		hasHandlers = YES;
		[handler installOnWindows];
	}
	if (hasHandlers) return;

	// Poster extensions host no editor, so they get an editorless handler that forwards swipes to PosterBoard.
	if (!gLooseHandler) gLooseHandler = [self new];
	[gLooseHandler install];
}

- (void)attachSwipeTo:(UIView *)target {
	if (!target) return;
	for (UIGestureRecognizer *recognizer in target.gestureRecognizers) {
		if ([recognizer.delegate isKindOfClass:[SokoLayoutSwipeHandler class]]) return;
	}

	UIPanGestureRecognizer *swipe = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
	swipe.delegate = self;
	swipe.maximumNumberOfTouches = 1;

	objc_setAssociatedObject(swipe, @selector(handleSwipe:), self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[target addGestureRecognizer:swipe];
}

- (PREditingSceneViewController *)editor {
	if (self.editingSceneViewController) return self.editingSceneViewController;

	PREditingSceneViewController *controller = [SokoPosterLayout editingSceneViewControllerForComplicationContainerViewController:self.complicationContainerViewController];
	if (controller) return controller;

	for (PREditingSceneViewController *candidate in [SokoPosterLayout editingSceneViewControllers]) {
		if (candidate.viewIfLoaded.window) return candidate;
	}
	return nil;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
	self.touchTimestamp = touch.timestamp;
	self.peakMovement = 0.0;
	return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
	PREditingSceneViewController *controller = [self editor];
	UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
	UIView *view = pan.view;
	BOOL loose = !controller;

	if (loose) {
		SokoDockGeometryReload();
		if (isnan(SokoDockGeometryBottomInset()) || [SokoPosterLayout isDodging] || !SokoIsPortrait(view.bounds)) return NO;
	} else if (![SokoPosterLayout canSwipeEditingSceneViewController:controller]) {
		return NO;
	}
	if ([NSProcessInfo processInfo].systemUptime - self.touchTimestamp > kSokoLayoutSwipeMaximumHold) return NO;

	CGPoint translation = [pan translationInView:view];
	if (fabs(translation.y) <= fabs(translation.x)) return NO;

	BOOL bottom = loose ? SokoEditorUsesBottomLayout() : [SokoPosterLayout editingSceneViewControllerUsesBottomLayout:controller];
	if (bottom ? translation.y >= 0.0 : translation.y <= 0.0) return NO;

	CGRect row = [SokoPosterLayout editingRowFrame];
	if (CGRectIsNull(row)) return NO;

	CGPoint location = [pan locationInView:view];
	CGPoint start = SokoScreenPoint(view, CGPointMake(location.x - translation.x, location.y - translation.y));
	return CGRectContainsPoint(CGRectInset(row, 0.0, -kSokoLayoutSwipeSlop), start);
}

- (void)handleSwipe:(UIPanGestureRecognizer *)pan {
	CGFloat travel = [pan translationInView:pan.view].y;
	if (fabs(travel) > fabs(self.peakMovement)) self.peakMovement = travel;
	if (pan.state != UIGestureRecognizerStateEnded) return;

	PREditingSceneViewController *controller = [self editor];
	BOOL loose = !controller;
	BOOL bottom;
	if (loose) {
		SokoDockGeometryReload();
		bottom = SokoEditorUsesBottomLayout();
	} else {
		if (![SokoPosterLayout canSwipeEditingSceneViewController:controller]) return;
		bottom = [SokoPosterLayout editingSceneViewControllerUsesBottomLayout:controller];
	}

	CGFloat direction = bottom ? -1.0 : 1.0;
	CGFloat distance = self.peakMovement * direction;
	CGFloat velocity = [pan velocityInView:pan.view].y * direction;
	if (distance < kSokoLayoutSwipeDistance && velocity < kSokoLayoutSwipeVelocity) return;

	if (loose) {
		SokoEditorRequestLayout(!bottom);
	} else {
		[SokoPosterLayout setUsesBottomLayout:!bottom forEditingSceneViewController:controller];
	}
}

@end
