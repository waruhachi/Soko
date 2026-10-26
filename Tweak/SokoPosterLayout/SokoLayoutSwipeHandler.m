#import "SokoLayoutSwipeHandler.h"

static const CGFloat kSokoLayoutSwipeDistance = 30.0;
static const CGFloat kSokoLayoutSwipeVelocity = 300.0;
static const CGFloat kSokoLayoutSwipeSlop = 24.0;
static const NSTimeInterval kSokoLayoutSwipeMaximumHold = 0.3;

@interface SokoLayoutSwipeHandler ()
@property (nonatomic, weak) PREditingSceneViewController *editingSceneViewController;
@property (nonatomic, weak) UIViewController *complicationContainerViewController;
@property (nonatomic) NSTimeInterval touchTimestamp;
@end

static CGPoint SokoScreenPoint(UIView *view, CGPoint point) {
	UIScreen *screen = view.window.screen;
	return screen ? [view convertPoint:point toCoordinateSpace:screen.coordinateSpace] : point;
}

@implementation SokoLayoutSwipeHandler

+ (void)installOnEditingSceneViewController:(PREditingSceneViewController *)controller {
	SokoLayoutSwipeHandler *handler = [self new];
	handler.editingSceneViewController = controller;
	[handler installOnView:controller.view];
}

+ (void)installOnComplicationContainerViewController:(UIViewController *)controller {
	if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.PosterBoard"]) return;

	SokoLayoutSwipeHandler *handler = [self new];
	handler.complicationContainerViewController = controller;
	[handler installOnView:controller.view];
}

- (void)installOnView:(UIView *)view {
	UIPanGestureRecognizer *swipe = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
	swipe.delegate = self;
	swipe.maximumNumberOfTouches = 1;

	objc_setAssociatedObject(swipe, @selector(handleSwipe:), self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[view addGestureRecognizer:swipe];
}

- (PREditingSceneViewController *)editor {
	if (self.editingSceneViewController) return self.editingSceneViewController;

	return [SokoPosterLayout editingSceneViewControllerForComplicationContainerViewController:self.complicationContainerViewController];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
	self.touchTimestamp = touch.timestamp;
	return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
	PREditingSceneViewController *controller = [self editor];
	if (![SokoPosterLayout canSwipeEditingSceneViewController:controller]) return NO;
	if ([NSProcessInfo processInfo].systemUptime - self.touchTimestamp > kSokoLayoutSwipeMaximumHold) return NO;

	UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
	UIView *view = pan.view;

	CGPoint velocity = [pan velocityInView:view];
	if (fabs(velocity.y) <= fabs(velocity.x)) return NO;

	BOOL bottom = [SokoPosterLayout editingSceneViewControllerUsesBottomLayout:controller];
	if (bottom ? velocity.y >= 0.0 : velocity.y <= 0.0) return NO;

	CGRect row = [SokoPosterLayout editingRowFrame];
	if (CGRectIsNull(row)) return NO;

	CGPoint translation = [pan translationInView:view];
	CGPoint location = [pan locationInView:view];
	CGPoint start = SokoScreenPoint(view, CGPointMake(location.x - translation.x, location.y - translation.y));
	return CGRectContainsPoint(CGRectInset(row, 0.0, -kSokoLayoutSwipeSlop), start);
}

- (void)handleSwipe:(UIPanGestureRecognizer *)pan {
	if (pan.state != UIGestureRecognizerStateEnded) return;

	PREditingSceneViewController *controller = [self editor];
	if (![SokoPosterLayout canSwipeEditingSceneViewController:controller]) return;

	BOOL bottom = [SokoPosterLayout editingSceneViewControllerUsesBottomLayout:controller];
	CGFloat direction = bottom ? -1.0 : 1.0;
	CGFloat distance = [pan translationInView:pan.view].y * direction;
	CGFloat velocity = [pan velocityInView:pan.view].y * direction;
	if (distance < kSokoLayoutSwipeDistance && velocity < kSokoLayoutSwipeVelocity) return;

	[SokoPosterLayout setUsesBottomLayout:!bottom forEditingSceneViewController:controller];
}

@end
