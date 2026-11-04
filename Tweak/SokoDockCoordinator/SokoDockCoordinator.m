#import "SokoDockCoordinator.h"

NSString *const SokoProminentDisplayVibrancyDidChangeNotification = @"SokoProminentDisplayVibrancyDidChangeNotification";
NSString *const SokoProminentDisplayContentAlphaDidChangeNotification = @"SokoProminentDisplayContentAlphaDidChangeNotification";

static const CGFloat kSokoDockBottomInsetWithoutButtons = 71.0;

static const void *kSokoDockCoordinatorKey = &kSokoDockCoordinatorKey;
static __weak SokoDockCoordinator *gActiveCoordinator;

@interface SokoDockCoordinator ()
@property (nonatomic, weak) CSCoverSheetViewController *coverSheetViewController;
@property (nonatomic, strong) SokoNotificationList *notificationList;
@property (nonatomic, strong) CSProminentLayoutController *layoutController;
@property (nonatomic, strong) BSUIVibrancyEffectView *hostView;
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL attached;
@property (nonatomic) CGFloat dockTopY;
@property (nonatomic) CGFloat dockBottomY;
@property (nonatomic, strong) NSMapTable<UIView *, NSNumber *> *depthEligibilityByReplica;
@property (nonatomic, strong) NSMapTable<FBScene *, NSNumber *> *nativeDepthVetoByScene;
@property (nonatomic, strong) NSMapTable<UIView *, FBScene *> *depthSceneByReplica;
@property (nonatomic, strong) NSHashTable<FBScene *> *overriddenDepthScenes;
@property (nonatomic) BOOL updatingWallpaperDepthSettings;
@end

@implementation SokoDockCoordinator

+ (BOOL)isSupported {
	Class coverSheetClass = NSClassFromString(@"CSCoverSheetViewController");
	if ([coverSheetClass instancesRespondToSelector:NSSelectorFromString(@"setComplicationContainerUsesBottomPosition:")]) return NO;

	Class dateClass = NSClassFromString(@"SBFLockScreenDateViewController");
	Class layoutClass = NSClassFromString(@"CSProminentLayoutController");
	Class listClass = NSClassFromString(@"NCNotificationListView");
	Class structuredClass = NSClassFromString(@"NCNotificationStructuredListViewController");
	Class containerClass = NSClassFromString(@"NCNotificationStructuredListView");

	BOOL listFooter = [listClass instancesRespondToSelector:@selector(setOverlayFooterViewEdgeInsets:)];
	BOOL containerFooter = [structuredClass instancesRespondToSelector:@selector(_updateListEdgeInsetsForSize:)] &&
		[containerClass instancesRespondToSelector:@selector(footerInsets)];

	BOOL coverSheet = [coverSheetClass instancesRespondToSelector:@selector(complicationContainerViewController)] &&
		[coverSheetClass instancesRespondToSelector:@selector(dateViewController)] &&
		[coverSheetClass instancesRespondToSelector:@selector(mainPageContentViewController)] &&
		[NSClassFromString(@"CSCoverSheetView") instancesRespondToSelector:@selector(slideableContentView)] &&
		[dateClass instancesRespondToSelector:@selector(setComplicationContainerViewController:)];

	BOOL layout = [layoutClass instancesRespondToSelector:@selector(initWithTraitEnvironment:)] &&
		[layoutClass instancesRespondToSelector:@selector(frameForElements:withBoundingRect:)];

	BOOL hosting = [UIViewController instancesRespondToSelector:@selector(bs_addChildViewController:withSuperview:)] &&
		[UIViewController instancesRespondToSelector:@selector(bs_removeChildViewController:)];

	return coverSheet && layout && hosting && (listFooter || containerFooter);
}

+ (instancetype)coordinatorForCoverSheetViewController:(CSCoverSheetViewController *)controller {
	if (!controller) return nil;

	SokoDockCoordinator *coordinator = objc_getAssociatedObject(controller, kSokoDockCoordinatorKey);
	if (!coordinator) {
		coordinator = [[SokoDockCoordinator alloc] initWithCoverSheetViewController:controller];
		objc_setAssociatedObject(controller, kSokoDockCoordinatorKey, coordinator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		objc_setAssociatedObject(controller.view, kSokoDockCoordinatorKey, coordinator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return coordinator;
}

+ (instancetype)coordinatorForCoverSheetView:(UIView *)view {
	return view ? objc_getAssociatedObject(view, kSokoDockCoordinatorKey) : nil;
}

+ (instancetype)activeCoordinator {
	return gActiveCoordinator;
}

- (instancetype)initWithCoverSheetViewController:(CSCoverSheetViewController *)controller {
	self = [super init];
	if (self) {
		_coverSheetViewController = controller;
		_notificationList = [[SokoNotificationList alloc] initWithCoverSheetViewController:controller dock:self];
		_dockTopY = NAN;
		_dockBottomY = NAN;
		_depthEligibilityByReplica = [NSMapTable weakToStrongObjectsMapTable];
		_nativeDepthVetoByScene = [NSMapTable weakToStrongObjectsMapTable];
		_depthSceneByReplica = [NSMapTable weakToWeakObjectsMapTable];
		_overriddenDepthScenes = [NSHashTable weakObjectsHashTable];

		NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
		[center addObserver:self selector:@selector(prominentDisplayVibrancyDidChange:) name:SokoProminentDisplayVibrancyDidChangeNotification object:nil];
		[center addObserver:self selector:@selector(prominentDisplayContentAlphaDidChange:) name:SokoProminentDisplayContentAlphaDidChangeNotification object:nil];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setEnabled:(BOOL)enabled {
	_enabled = enabled;
	[self publishDockGeometry];
	[self refresh];
}

- (void)refresh {
	if ([self shouldHostDock]) {
		[self attachIfNeeded];
	} else {
		[self detach];
	}

	[self.coverSheetViewController.viewIfLoaded setNeedsLayout];
	[self.notificationList updateLayout];
	[self updateWallpaperDepthEffectSource];
}

- (void)coverSheetViewDidLayout {
	[self publishDockGeometry];

	if (![self shouldHostDock]) {
		if (self.attached) [self refresh];
		[self updateWallpaperDepthEffectSource];
		return;
	}

	[self attachIfNeeded];
	if (!self.attached) return;

	[self layoutDock];
	[self.notificationList updateLayout];
	[self updateWallpaperDepthEffectSource];
}

- (BOOL)allowsWallpaperDepthEffect {
	// Opacity changes during locking; eligibility follows the actual hosted layout.
	return self.attached && !isnan(self.dockTopY) && !self.hostView.hidden && [self shouldHostDock] &&
		SokoIsPortrait(self.coverSheetViewController.viewIfLoaded.bounds);
}

- (void)updateWallpaperDepthEffectSource {
	[self updateWallpaperDepthSettings];
	CSCoverSheetView *coverSheet = (CSCoverSheetView *)self.coverSheetViewController.viewIfLoaded;
	if (![coverSheet respondsToSelector:@selector(wallpaperFloatingLayerContainerView)]) return;

	Class replicaClass = NSClassFromString(@"PBUIPosterFloatingLayerReplica");
	if (!replicaClass) return;
	BOOL allowed = self.allowsWallpaperDepthEffect;
	for (UIView *replica in coverSheet.wallpaperFloatingLayerContainerView.subviews) {
		if (![replica isKindOfClass:replicaClass] || ![replica respondsToSelector:@selector(setNeedsSourceUpdate)]) continue;
		NSNumber *previous = [self.depthEligibilityByReplica objectForKey:replica];
		if (previous && previous.boolValue == allowed) continue;

		// Cache before the native refresh, which can request another layout pass.
		[self.depthEligibilityByReplica setObject:@(allowed) forKey:replica];
		if (allowed || previous.boolValue) [(PBUIPortalReplicaView *)replica setNeedsSourceUpdate];
	}
}

- (void)registerWallpaperDepthScene:(FBScene *)scene forReplica:(UIView *)replica {
	if (!scene || !replica ||
		![scene.settings respondsToSelector:@selector(pr_isDepthEffectDisallowed)] ||
		![scene respondsToSelector:@selector(updateSettings:withTransitionContext:)]) return;
	if ([self.depthSceneByReplica objectForKey:replica] == scene &&
		[self.nativeDepthVetoByScene objectForKey:scene]) return;

	[self.depthSceneByReplica setObject:scene forKey:replica];
	if (![self.nativeDepthVetoByScene objectForKey:scene]) {
		[self.nativeDepthVetoByScene setObject:@([scene.settings pr_isDepthEffectDisallowed]) forKey:scene];
	}
	// Source resolution can happen inside native layout. Publish after it returns.
	__weak SokoDockCoordinator *weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		[weakSelf updateWallpaperDepthEffectSource];
	});
}

- (BOOL)hasWallpaperDepthReplicaForScene:(FBScene *)scene {
	CSCoverSheetView *coverSheet = (CSCoverSheetView *)self.coverSheetViewController.viewIfLoaded;
	if (![coverSheet respondsToSelector:@selector(wallpaperFloatingLayerContainerView)]) return NO;
	for (UIView *replica in coverSheet.wallpaperFloatingLayerContainerView.subviews) {
		if ([self.depthSceneByReplica objectForKey:replica] == scene) return YES;
	}
	return NO;
}

- (void)prepareWallpaperDepthScene:(FBScene *)scene settings:(FBSMutableSceneSettings *)settings {
	if (![self.nativeDepthVetoByScene objectForKey:scene] || self.updatingWallpaperDepthSettings ||
		![settings respondsToSelector:@selector(pr_setDepthEffectDisallowed:)]) return;

	BOOL nativeVeto = [settings pr_isDepthEffectDisallowed];
	BOOL rowConfigured = ![settings respondsToSelector:@selector(pr_isComplicationRowConfigured)] || [settings pr_isComplicationRowConfigured];
	BOOL allowed = rowConfigured && self.allowsWallpaperDepthEffect && [self hasWallpaperDepthReplicaForScene:scene];
	BOOL overridden = [self.overriddenDepthScenes containsObject:scene];
	if (!rowConfigured) {
		// Removing the last widget supplies fresh native policy, not a copied override.
		[self.overriddenDepthScenes removeObject:scene];
		overridden = NO;
	}
	// A copied NO is ours until restoration completes, even if layout just changed.
	if (nativeVeto || !overridden) [self.nativeDepthVetoByScene setObject:@(nativeVeto) forKey:scene];
	if (allowed) {
		if (nativeVeto) [self.overriddenDepthScenes addObject:scene];
		[settings pr_setDepthEffectDisallowed:NO];
	} else if (overridden) {
		[settings pr_setDepthEffectDisallowed:[[self.nativeDepthVetoByScene objectForKey:scene] boolValue]];
		[self.overriddenDepthScenes removeObject:scene];
	}
}

- (void)updateWallpaperDepthSettings {
	if (self.updatingWallpaperDepthSettings) return;
	for (FBScene *scene in self.nativeDepthVetoByScene.keyEnumerator.allObjects) {
		BOOL current = [self hasWallpaperDepthReplicaForScene:scene];
		BOOL rowConfigured = ![scene.settings respondsToSelector:@selector(pr_isComplicationRowConfigured)] || [scene.settings pr_isComplicationRowConfigured];
		BOOL allowed = rowConfigured && self.allowsWallpaperDepthEffect && current;
		BOOL disallowed = allowed ? NO : [[self.nativeDepthVetoByScene objectForKey:scene] boolValue];
		if ([scene.settings pr_isDepthEffectDisallowed] == disallowed) {
			if (!allowed) [self.overriddenDepthScenes removeObject:scene];
			if (!current) [self.nativeDepthVetoByScene removeObjectForKey:scene];
			continue;
		}
		FBSMutableSceneSettings *settings = [scene.settings mutableCopy];
		if (![settings respondsToSelector:@selector(pr_setDepthEffectDisallowed:)]) continue;
		[settings pr_setDepthEffectDisallowed:disallowed];
		self.updatingWallpaperDepthSettings = YES;
		@try {
			if (allowed) [self.overriddenDepthScenes addObject:scene];
			[scene updateSettings:settings withTransitionContext:nil];
			if (!allowed) [self.overriddenDepthScenes removeObject:scene];
			if (!current) [self.nativeDepthVetoByScene removeObjectForKey:scene];
		} @finally {
			self.updatingWallpaperDepthSettings = NO;
		}
	}
}

- (BOOL)shouldHostDock {
	if (!self.enabled) return NO;

	UIViewController *complications = self.coverSheetViewController.complicationContainerViewController;
	if ([complications respondsToSelector:@selector(widgetDescriptors)]) {
		NSArray *descriptors = ((CSComplicationContainerViewController *)complications).widgetDescriptors;
		return [descriptors isKindOfClass:[NSArray class]] && descriptors.count > 0;
	}

	return complications && self.complicationContainerHeight > 0.0;
}

- (BOOL)dockVisible {
	if (!self.attached || self.hostView.hidden || isnan(self.dockTopY)) return NO;

	UIView *complicationsView = self.coverSheetViewController.complicationContainerViewController.viewIfLoaded;
	return complicationsView && !complicationsView.hidden && complicationsView.alpha > 0.01;
}

- (UIView *)dockContainerView {
	return self.hostView.superview;
}

- (double)complicationContainerHeight {
	CSCoverSheetViewController *coverSheet = self.coverSheetViewController;
	if (class_getInstanceVariable(object_getClass(coverSheet), "_portraitComplicationContainerHeight")) {
		return SokoIvarDouble(coverSheet, "_portraitComplicationContainerHeight");
	}

	return SokoIvarDouble(coverSheet, "_complicationContainerHeight");
}

- (UIView *)contentView {
	if ([self.hostView respondsToSelector:@selector(contentView)]) return self.hostView.contentView;

	return self.hostView;
}

- (BSUIVibrancyEffectView *)makeHostView {
	Class vibrancyClass = NSClassFromString(@"BSUIVibrancyEffectView") ?: [UIView class];

	BSUIVibrancyEffectView *host = [[vibrancyClass alloc] initWithFrame:CGRectZero];
	host.userInteractionEnabled = NO;
	host.layer.name = @"Soko Widget Dock";
	return host;
}

- (void)insertHostViewIfNeeded {
	CSCoverSheetView *coverSheetView = (CSCoverSheetView *)self.coverSheetViewController.viewIfLoaded;
	UIView *slideableContentView = coverSheetView.slideableContentView;
	if (!self.hostView) self.hostView = [self makeHostView];
	if (self.hostView.superview == slideableContentView) return;

	UIView *dateContainer = SokoIvarObject(coverSheetView, "_dateTimeClippingView");
	if (dateContainer.superview == slideableContentView) {
		[slideableContentView insertSubview:self.hostView aboveSubview:dateContainer];
	} else {
		[slideableContentView insertSubview:self.hostView atIndex:0];
	}
}

- (void)attachIfNeeded {
	CSCoverSheetViewController *coverSheet = self.coverSheetViewController;
	UIViewController *complications = coverSheet.complicationContainerViewController;
	SBFLockScreenDateViewController *dateViewController = coverSheet.dateViewController;
	CSCoverSheetView *coverSheetView = (CSCoverSheetView *)coverSheet.viewIfLoaded;
	if (!complications || !dateViewController || !coverSheetView.slideableContentView) return;

	[self insertHostViewIfNeeded];

	UIView *content = [self contentView];
	BOOL hosted = complications.parentViewController == coverSheet && complications.viewIfLoaded.superview == content;
	if (!hosted) {
		if (dateViewController.complicationContainerViewController == complications) {
			dateViewController.complicationContainerViewController = nil;
		} else if (complications.parentViewController) {
			[complications.parentViewController bs_removeChildViewController:complications];
		}

		[coverSheet bs_addChildViewController:complications withSuperview:content];
		complications.view.frame = content.bounds;
		complications.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	}

	self.attached = YES;
	gActiveCoordinator = self;

	if (!hosted) {
		[self syncVibrancy];
		[self syncRowAlpha];
	}
}

- (void)detach {
	if (!self.attached) return;

	CSCoverSheetViewController *coverSheet = self.coverSheetViewController;
	UIViewController *complications = coverSheet.complicationContainerViewController;
	if (complications.parentViewController == coverSheet) [coverSheet bs_removeChildViewController:complications];
	[self.hostView removeFromSuperview];

	self.attached = NO;
	self.dockTopY = NAN;
	self.dockBottomY = NAN;
	if (gActiveCoordinator == self) gActiveCoordinator = nil;

	if (complications) coverSheet.dateViewController.complicationContainerViewController = complications;
}

- (CSProminentLayoutController *)layoutController {
	if (!_layoutController) {
		Class layoutClass = NSClassFromString(@"CSProminentLayoutController");
		_layoutController = [[layoutClass alloc] initWithTraitEnvironment:(id<UITraitEnvironment>)self.coverSheetViewController.view];
	}
	return _layoutController;
}

- (CGFloat)dockBottomYInCoverSheetView:(CSCoverSheetView *)coverSheetView {
	CGFloat centerY;
	if (SokoQuickActionButtonCenterY(coverSheetView, &centerY)) return centerY - kSokoDockBottomToButtonCenter;

	return CGRectGetHeight(coverSheetView.bounds) - coverSheetView.safeAreaInsets.bottom - kSokoDockBottomInsetWithoutButtons;
}

- (void)publishDockGeometry {
	CSCoverSheetView *coverSheetView = (CSCoverSheetView *)self.coverSheetViewController.viewIfLoaded;
	CGRect bounds = coverSheetView.bounds;
	if (CGRectGetHeight(bounds) <= 0.0 || !SokoIsPortrait(bounds)) return;

	SokoDockGeometryPublishBottomInset(CGRectGetHeight(bounds) - [self dockBottomYInCoverSheetView:coverSheetView]);
}

- (void)layoutDock {
	CSCoverSheetView *coverSheetView = (CSCoverSheetView *)self.coverSheetViewController.viewIfLoaded;
	UIView *host = self.hostView;
	if (!coverSheetView || !host) return;

	CGRect bounds = coverSheetView.bounds;
	CGRect row = SokoIsPortrait(bounds) ? [self.layoutController frameForElements:kSokoComplicationRowElement withBoundingRect:bounds] : CGRectNull;
	if (CGRectIsNull(row) || CGRectGetHeight(row) <= 0.0 || CGRectGetWidth(row) <= 0.0) {
		host.hidden = YES;
		self.dockTopY = NAN;
		self.dockBottomY = NAN;
		return;
	}

	row.origin.y = [self dockBottomYInCoverSheetView:coverSheetView] - CGRectGetHeight(row);
	self.dockTopY = CGRectGetMinY(row);
	self.dockBottomY = CGRectGetMaxY(row);

	host.hidden = NO;
	host.transform = CGAffineTransformIdentity;
	host.frame = row;
	[self applyDateViewScale:coverSheetView];

	UIView *complicationsView = self.coverSheetViewController.complicationContainerViewController.viewIfLoaded;
	UIView *content = [self contentView];
	if (complicationsView.superview == content && !CGRectEqualToRect(complicationsView.frame, content.bounds)) {
		complicationsView.frame = content.bounds;
	}
}

- (void)applyDateViewScale:(CSCoverSheetView *)coverSheetView {
	double scale = [coverSheetView respondsToSelector:@selector(dateViewScale)] ? coverSheetView.dateViewScale : 1.0;
	if (scale <= 0.0 || fabs(scale - 1.0) <= 0.0001) return;

	CGRect bounds = coverSheetView.bounds;
	CGPoint pivot = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
	CGPoint center = self.hostView.center;
	CGFloat tx = (pivot.x - center.x) * (1.0 - scale);
	CGFloat ty = (pivot.y - center.y) * (1.0 - scale);
	self.hostView.transform = CGAffineTransformMake(scale, 0.0, 0.0, scale, tx, ty);
}

- (CSProminentDisplayViewController *)prominentDisplayViewController {
	return SokoIvarObject(self.coverSheetViewController.dateViewController, "_prominentDisplayViewController");
}

- (void)syncVibrancy {
	CSProminentDisplayView *prominentView = (CSProminentDisplayView *)[self prominentDisplayViewController].viewIfLoaded;
	if (![prominentView respondsToSelector:@selector(vibrancyEffectView)]) return;

	BSUIVibrancyEffectView *source = (BSUIVibrancyEffectView *)prominentView.vibrancyEffectView;
	BSUIVibrancyEffectView *host = self.hostView;
	if (![source respondsToSelector:@selector(configuration)] || ![host respondsToSelector:@selector(setConfiguration:)]) return;

	if (source.configuration) host.configuration = source.configuration;
	if ([source respondsToSelector:@selector(contentType)] && [host respondsToSelector:@selector(setContentType:)]) {
		host.contentType = source.contentType;
	}
}

- (void)syncRowAlpha {
	CSProminentDisplayViewController *prominent = [self prominentDisplayViewController];
	if (!self.hostView || ![prominent respondsToSelector:@selector(complicationRowAlpha)]) return;

	self.hostView.alpha = prominent.complicationRowAlpha;
}

- (void)prominentDisplayContentAlphaDidChange:(NSNotification *)notification {
	if (self.attached && notification.object == [self prominentDisplayViewController]) [self syncRowAlpha];
}

- (void)prominentDisplayVibrancyDidChange:(NSNotification *)notification {
	if (self.attached && notification.object == [self prominentDisplayViewController]) [self syncVibrancy];
}

@end
