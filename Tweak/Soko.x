#import "Soko.h"

static BOOL gActivePosterUsesBottomLayout;
static __thread const void *gWallpaperDepthQuerySettings;
static __weak CSCoverSheetViewController *gCoverSheetViewController;
static id gPosterPreviewLaunchObserver;

static SokoDockCoordinator *SokoCoordinator(void) {
	CSCoverSheetViewController *coverSheet = gCoverSheetViewController;
	return coverSheet.isViewLoaded ? [SokoDockCoordinator coordinatorForCoverSheetViewController:coverSheet] : nil;
}

static void SokoSetActivePosterUsesBottomLayout(BOOL usesBottomLayout) {
	SokoDockPublishActiveUsesBottomLayout(usesBottomLayout);
	if (usesBottomLayout == gActivePosterUsesBottomLayout) return;

	gActivePosterUsesBottomLayout = usesBottomLayout;
	[SokoCoordinator() setEnabled:usesBottomLayout];
}

static void SokoRefreshDockSoon(void) {
	dispatch_async(dispatch_get_main_queue(), ^{
		[SokoCoordinator() refresh];
	});
}

static void SokoPost(NSString *name, id object) {
	[[NSNotificationCenter defaultCenter] postNotificationName:name object:object];
}

static BOOL SokoMoveFooter(UIView *footer, UIView *listView, CGFloat *movedCenterY) {
	SokoNotificationList *notificationList = [SokoDockCoordinator activeCoordinator].notificationList;
	CGFloat centerY;
	if (!footer || ![notificationList getFooterCenterY:&centerY forListView:listView]) return NO;

	CGFloat scale = listView.traitCollection.displayScale ?: 1.0;
	CGFloat height = CGRectGetHeight(footer.bounds);
	CGFloat minY = round((centerY - height / 2.0) * scale) / scale;

	[UIView performWithoutAnimation:^{
		footer.center = CGPointMake(footer.center.x, minY + height / 2.0);
	}];

	if (movedCenterY) *movedCenterY = minY + height / 2.0;
	return YES;
}

static UIEdgeInsets SokoAdjustedFooterInsets(UIEdgeInsets insets, CSCombinedListViewController *combinedListViewController) {
	SokoNotificationList *notificationList = [SokoDockCoordinator activeCoordinator].notificationList;
	if (!notificationList) return insets;

	return [notificationList footerInsetsByAdjustingInsets:insets forCombinedListViewController:combinedListViewController];
}

static BOOL SokoAllowsAddGestureOverRow(BOOL (^orig)(void)) {
	[SokoPosterLayout setIgnoringGraphicComplications:YES];
	BOOL allowed = orig();
	[SokoPosterLayout setIgnoringGraphicComplications:NO];

	return allowed;
}

%group SokoDock

%hook CSCoverSheetViewController

- (void)viewDidLoad {
	%orig;

	gCoverSheetViewController = self;
	[[SokoDockCoordinator coordinatorForCoverSheetViewController:self] setEnabled:gActivePosterUsesBottomLayout];
}

- (void)_updateComplicationsContainerView {
	%orig;

	[[SokoDockCoordinator coordinatorForCoverSheetView:self.viewIfLoaded].notificationList updateLayout];
}

- (double)listMinY {
	double listMinY = %orig;

	SokoNotificationList *notificationList = [SokoDockCoordinator coordinatorForCoverSheetView:self.viewIfLoaded].notificationList;
	return notificationList ? [notificationList listMinYByAdjustingListMinY:listMinY] : listMinY;
}

%end

%hook CSCoverSheetView

- (void)layoutSubviews {
	%orig;

	[[SokoDockCoordinator coordinatorForCoverSheetView:self] coverSheetViewDidLayout];
}

- (void)_layoutDateView {
	%orig;

	[[SokoDockCoordinator coordinatorForCoverSheetView:self] coverSheetViewDidLayout];
}

%end

%hook CSComplicationManager

- (void)_updateComplicationsForActivePosterConfiguration {
	%orig;

	PRSWallpaperObserverState *state = SokoIvarObject(self, "_wallpaperState");
	PRSPosterConfiguration *configuration = [state respondsToSelector:@selector(activeLock)] ? state.activeLock : nil;
	[SokoPosterModel applyPendingDefaultLayoutToConfiguration:configuration];

	BOOL usesBottomLayout;
	if (SokoLiquidAssClockEnabled()) {
		usesBottomLayout = configuration && SokoLiquidAssUserInfoUsesBottomLayout(SokoLiquidAssUserInfoForConfiguration(configuration));
	} else {
		id layout = nil;
		if ([configuration respondsToSelector:@selector(pr_loadComplicationLayoutWithError:)]) {
			layout = [configuration pr_loadComplicationLayoutWithError:nil];
		}

		usesBottomLayout = [SokoPosterModel complicationLayoutUsesBottomLayout:layout];
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		SokoSetActivePosterUsesBottomLayout(usesBottomLayout);
	});
}

%end

%hook CSProminentDisplayViewController

- (void)_updateViewColors {
	%orig;

	SokoPost(SokoProminentDisplayVibrancyDidChangeNotification, self);
}

- (void)setVibrancyContentType:(long long)contentType {
	%orig;

	SokoPost(SokoProminentDisplayVibrancyDidChangeNotification, self);
}

- (void)interactiveTransition:(id)transition didUpdate:(double)progress {
	%orig;

	SokoPost(SokoProminentDisplayVibrancyDidChangeNotification, self);
}

- (void)setContentAlpha:(double)alpha forElements:(unsigned long long)elements {
	%orig;

	if (elements & kSokoComplicationRowElement) SokoPost(SokoProminentDisplayContentAlphaDidChangeNotification, self);
}

%end

%end

%group SokoDockListFooter

%hook NCNotificationListView

- (void)_layoutOverlayFooterViewIfNecessary {
	%orig;

	SokoMoveFooter(self.overlayFooterView, self, NULL);
}

%end

%end

%group SokoDockContainerFooter

%hook NCNotificationStructuredListView

- (void)layoutSubviews {
	%orig;

	CGFloat centerY;
	if (!SokoMoveFooter(self.footerView, self, &centerY)) return;

	id<NCNotificationStructuredListViewDelegate> delegate = self.delegate;
	if ([delegate respondsToSelector:@selector(notificationStructuredListView:didChangeFooterCenterY:)]) {
		[delegate notificationStructuredListView:self didChangeFooterCenterY:centerY];
	}
}

%end

%end

%group SokoDockWidgetDescriptors

%hook CSComplicationContainerViewController

- (void)setWidgetDescriptors:(NSArray *)widgetDescriptors {
	%orig;

	SokoRefreshDockSoon();
}

%end

%end

%group SokoDockWidgetGrid

%hook CSWidgetGridViewController

- (void)setComplicationDescriptors:(NSArray *)complicationDescriptors iconLayout:(id)iconLayout {
	%orig;

	SokoRefreshDockSoon();
}

%end

%end

%group SokoDockFooterInsets

%hook CSCombinedListViewController

- (UIEdgeInsets)notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:(id)structuredListViewController {
	UIEdgeInsets insets = %orig;

	return SokoAdjustedFooterInsets(insets, self);
}

%end

%end

%group SokoDockFooterInsetsForOrientation

%hook CSCombinedListViewController

- (UIEdgeInsets)notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:(id)structuredListViewController forOrientation:(long long)orientation {
	UIEdgeInsets insets = %orig;

	return SokoAdjustedFooterInsets(insets, self);
}

%end

%end

%group SokoPoster

%hook CSProminentLayoutController

- (CGRect)_frameForElement:(unsigned long long)element withBoundingRect:(CGRect)rect variant:(unsigned long long)variant {
	CGRect frame = %orig;

	return [SokoPosterLayout frameByAdjustingFrame:frame forElement:element boundingRect:rect variant:variant layoutController:self];
}

- (CGRect)complicationRowElementEditingReticleFrameWithBoundingRect:(CGRect)rect {
	CGRect frame = %orig;

	return [SokoPosterLayout reticleFrameByAdjustingFrame:frame layoutController:self boundingRect:rect];
}

%end

%hook PRComplicationContainerViewController

- (void)viewDidLoad {
	%orig;

	[SokoPosterLayout registerComplicationContainerViewController:self];
	[SokoLayoutSwipeHandler installOnComplicationContainerViewController:self];
}

%end

%hook PREditorRootViewController

- (void)loadView {
	%orig;

	[SokoEditorChrome registerEditorRootViewController:self];
}

%end

%hook PREditingSceneViewController

- (instancetype)initWithProvider:(id)provider contents:(id)contents configurableOptions:(id)configurableOptions configuredProperties:(PRPosterConfiguredProperties *)configuredProperties additionalInfo:(id)additionalInfo {
	self = %orig;

	if (self) [SokoPosterLayout setInitialComplicationLayout:configuredProperties.complicationLayout forEditingSceneViewController:self];
	return self;
}

- (void)viewDidLoad {
	%orig;

	if ([SokoPosterLayout registerEditingSceneViewController:self]) [SokoLayoutSwipeHandler installOnEditingSceneViewController:self];
}

- (BOOL)_hasGraphicComplications {
	return [SokoPosterLayout isIgnoringGraphicComplications] ? NO : %orig;
}

- (void)setPresentedComplicationsGallery:(UINavigationController *)gallery {
	%orig;

	[SokoPosterLayout editingSceneViewControllerDidChangePresentation:self];
}

- (void)setPresentedInlineComplicationsGallery:(UINavigationController *)gallery {
	%orig;

	[SokoPosterLayout editingSceneViewControllerDidChangePresentation:self];
}

%end

%hook PREditor

- (void)setCoveredByHostModalPresentation:(BOOL)covered {
	%orig;

	[SokoPosterLayout setCoveredByHostModalPresentation:covered];
}

%end

%end

%group SokoPosterPreview

%hook SokoLockScreenPosterCollectionViewCell

- (void)layoutSubviews {
	%orig;
	[SokoPosterLayout updateDepthMaskForPosterCell:self];
}

- (void)prepareForReuse {
	%orig;
	[SokoPosterLayout clearDepthMaskForPosterCell:self];
}

%end

%end

%group SokoSavedDepthEffect

%hook FBSSceneSettings

- (BOOL)pr_isDepthEffectDisallowed {
	return gWallpaperDepthQuerySettings == (__bridge const void *)self ? NO : %orig;
}

%end

%hook PBUIPosterLockViewController

- (id)portalSourceForReplicaView:(UIView *)replica {
	NSString *reason = SokoIvarObject(replica, "_reason");
	if (![SokoCoordinator() allowsWallpaperDepthEffect] ||
		![reason isKindOfClass:[NSString class]] || ![reason isEqualToString:@"CSCoverSheetViewController"]) return %orig;

	FBScene *scene = SokoIvarObject(self, "_scene");
	FBSSceneSettings *settings = [scene respondsToSelector:@selector(settings)] ? scene.settings : nil;
	if (!settings) return %orig;
	[SokoCoordinator() registerWallpaperDepthScene:scene forReplica:replica];

	// Resolve the native source while the scene correction is being published.
	// The renderer's separate depth preference remains intact.
	const void *previous = gWallpaperDepthQuerySettings;
	gWallpaperDepthQuerySettings = (__bridge const void *)settings;
	@try {
		return %orig;
	} @finally {
		gWallpaperDepthQuerySettings = previous;
	}
}

%end

%end

%group SokoSavedDepthSettings

%hook PBUIPosterViewController

- (void)scene:(FBScene *)scene willUpdateSettings:(FBSMutableSceneSettings *)settings withTransitionContext:(id)context {
	%orig;
	if (scene == SokoIvarObject(self, "_scene")) {
		[SokoCoordinator() prepareWallpaperDepthScene:scene settings:settings];
	}
}

%end

%end

%group SokoPosterWidgetConfiguration

%hook PREditingSceneViewController

- (void)setPresentedWidgetConfigurationViewController:(UIViewController *)controller {
	%orig;

	[SokoPosterLayout editingSceneViewControllerDidChangePresentation:self];
}

%end

%end

%group SokoPosterComplicationWidgetConfiguration

%hook PREditingSceneViewController

- (void)setPresentedComplicationWidgetConfigurationViewController:(UIViewController *)controller {
	%orig;

	[SokoPosterLayout editingSceneViewControllerDidChangePresentation:self];
}

- (void)setPresentedControlsGallery:(UIViewController *)gallery {
	%orig;

	[SokoPosterLayout editingSceneViewControllerDidChangePresentation:self];
}

- (void)setPresentedControlWidgetConfigurationViewController:(UIViewController *)controller {
	%orig;

	[SokoPosterLayout editingSceneViewControllerDidChangePresentation:self];
}

%end

%end

%group SokoPosterAddGesture

%hook PREditingSceneViewController

- (BOOL)_shouldAllowAddComplicationsTapGesture {
	if (![SokoPosterLayout usesBottomEditingRow]) return %orig;

	return SokoAllowsAddGestureOverRow(^{
		return %orig;
	});
}

%end

%end

%group SokoPosterAddGestureForLocation

%hook PREditingSceneViewController

- (BOOL)_shouldAllowAddComplicationsTapGestureForLocation:(long long)location {
	if (location != 0 || ![SokoPosterLayout usesBottomEditingRow]) return %orig;

	return SokoAllowsAddGestureOverRow(^{
		return %orig;
	});
}

%end

%end

%group SokoPosterModel

%hook PRPosterComplicationLayout

- (void)encodeWithCoder:(NSCoder *)coder {
	%orig;

	[SokoPosterModel encodeComplicationLayout:self withCoder:coder];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = %orig;

	[SokoPosterModel decodeComplicationLayout:self withCoder:coder];
	return self;
}

- (void)encodeWithBSXPCCoder:(id)coder {
	%orig;

	[SokoPosterModel encodeComplicationLayout:self withCoder:coder];
}

- (instancetype)initWithBSXPCCoder:(id)coder {
	self = %orig;

	[SokoPosterModel decodeComplicationLayout:self withCoder:coder];
	return self;
}

- (id)copyWithZone:(NSZone *)zone {
	id copy = %orig;

	[SokoPosterModel copyBottomLayoutFromComplicationLayout:self toComplicationLayout:copy];
	return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
	id copy = %orig;

	[SokoPosterModel copyBottomLayoutFromComplicationLayout:self toComplicationLayout:copy];
	return copy;
}

- (BOOL)isEqualToComplicationLayout:(id)layout {
	return %orig && [SokoPosterModel complicationLayout:self hasSameBottomLayoutAsComplicationLayout:layout];
}

- (BOOL)isEqual:(id)object {
	return %orig && [SokoPosterModel complicationLayout:self hasSameBottomLayoutAsComplicationLayout:object];
}

%end

%hook PRPosterConfiguredProperties

- (void)setComplicationLayout:(id)layout {
	if (layout) {
		NSNumber *editorValue = [SokoPosterLayout bottomLayoutValueForDismissingEditor];
		if (editorValue) {
			[SokoPosterModel setBottomLayoutValue:editorValue forComplicationLayout:layout];
		} else if (![SokoPosterModel bottomLayoutValueForComplicationLayout:layout]) {
			[SokoPosterModel copyBottomLayoutFromComplicationLayout:self.complicationLayout toComplicationLayout:layout];
		}
	}

	%orig;
}

%end

%end

%group SokoLiquidAssEditorDefaults

%hook LGClockEditorState

- (void)setController:(UIViewController *)controller {
	%orig;
	SokoLiquidAssPrepareEditorDefaults(controller);
}

%end

%hook PRPosterConfiguration

- (NSDictionary *)loadUserInfoWithError:(NSError **)error {
	NSError *loadError = nil;
	NSDictionary *info = %orig(&loadError);
	if (error) *error = loadError;
	return SokoLiquidAssEditorUserInfo(self, info, loadError);
}

%end

%end

%group SokoLiquidAssPoster

%hook CSProminentLayoutController

- (CGRect)_frameForElement:(unsigned long long)element withBoundingRect:(CGRect)rect variant:(unsigned long long)variant {
	CGRect frame = %orig;

	return [SokoPosterLayout frameByAdjustingFrame:frame forElement:element boundingRect:rect variant:variant layoutController:self];
}

%end

%hook PRComplicationContainerViewController

- (void)viewDidLoad {
	%orig;

	[SokoPosterLayout registerComplicationContainerViewController:self];
}

%end

%end

%group SokoPhotosEditor

%hook PUWallpaperPosterEditorController

- (BOOL)_createHintLabelIfNeeded {
	BOOL created = %orig;

	self.hintLabel.hidden = YES;
	return created;
}

- (void)_updateHintLabelAnimated:(BOOL)animated {
	%orig;

	self.hintLabel.hidden = YES;
}

%end

%end

static void SokoImageAdded(const struct mach_header *header, intptr_t slide) {
	if (!objc_getClass("PUWallpaperPosterEditorController")) return;

	static dispatch_once_t once;
	dispatch_once(&once, ^{
		%init(SokoPhotosEditor);
	});
}

static void SokoInitDock(void) {
	if (![SokoDockCoordinator isSupported]) return;

	%init(SokoDock);
	if ([objc_getClass("FBSSceneSettings") instancesRespondToSelector:@selector(pr_isDepthEffectDisallowed)] &&
		[objc_getClass("PBUIPosterLockViewController") instancesRespondToSelector:@selector(portalSourceForReplicaView:)]) {
		%init(SokoSavedDepthEffect);
		if ([objc_getClass("PBUIPosterViewController") instancesRespondToSelector:@selector(scene:willUpdateSettings:withTransitionContext:)]) {
			%init(SokoSavedDepthSettings);
		}
	}

	if ([objc_getClass("NCNotificationListView") instancesRespondToSelector:@selector(_layoutOverlayFooterViewIfNecessary)]) {
		%init(SokoDockListFooter);
	} else if ([objc_getClass("NCNotificationStructuredListView") instancesRespondToSelector:@selector(footerView)]) {
		%init(SokoDockContainerFooter);
	}

	if ([objc_getClass("CSComplicationContainerViewController") instancesRespondToSelector:@selector(setWidgetDescriptors:)]) {
		%init(SokoDockWidgetDescriptors);
	} else if ([objc_getClass("CSWidgetGridViewController") instancesRespondToSelector:@selector(setComplicationDescriptors:iconLayout:)]) {
		%init(SokoDockWidgetGrid);
	}

	Class combinedListClass = objc_getClass("CSCombinedListViewController");
	if ([combinedListClass instancesRespondToSelector:@selector(notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:forOrientation:)]) {
		%init(SokoDockFooterInsetsForOrientation);
	} else if ([combinedListClass instancesRespondToSelector:@selector(notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:)]) {
		%init(SokoDockFooterInsets);
	}
}

static void SokoInitLiquidAssPoster(void) {
	%init(SokoLiquidAssPoster);
	if ([objc_getClass("LGClockEditorState") instancesRespondToSelector:@selector(setController:)] &&
		[objc_getClass("PRPosterConfiguration") instancesRespondToSelector:@selector(loadUserInfoWithError:)]) {
		%init(SokoLiquidAssEditorDefaults);
	}

	SokoDockGeometryObserve(^{
		[SokoPosterLayout relayoutAnimated:YES];
	});
}

static BOOL SokoInitPosterPreview(void) {
	static BOOL initialized;
	if (initialized) return YES;
	Class posterCellClass = NSClassFromString(@"PosterBoard.LockScreenPosterCollectionViewCell") ?:
		NSClassFromString(@"_TtC11PosterBoard34LockScreenPosterCollectionViewCell");
	if (posterCellClass) {
		%init(SokoPosterPreview, SokoLockScreenPosterCollectionViewCell = posterCellClass);
		initialized = YES;
	}
	return initialized;
}

static void SokoInitPoster(void) {
	if (![SokoPosterLayout isSupported]) return;
	if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.PosterBoard"] && !SokoInitPosterPreview()) {
		gPosterPreviewLaunchObserver = [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *notification) {
			SokoInitPosterPreview();
			[NSNotificationCenter.defaultCenter removeObserver:gPosterPreviewLaunchObserver];
			gPosterPreviewLaunchObserver = nil;
		}];
	}
	if (SokoLiquidAssClockEnabled()) {
		SokoInitLiquidAssPoster();
		return;
	}

	%init(SokoPoster);

	Class editingSceneClass = objc_getClass("PREditingSceneViewController");
	if ([editingSceneClass instancesRespondToSelector:@selector(setPresentedComplicationWidgetConfigurationViewController:)]) {
		%init(SokoPosterComplicationWidgetConfiguration);
	} else if ([editingSceneClass instancesRespondToSelector:@selector(setPresentedWidgetConfigurationViewController:)]) {
		%init(SokoPosterWidgetConfiguration);
	}

	if ([editingSceneClass instancesRespondToSelector:@selector(_shouldAllowAddComplicationsTapGestureForLocation:)]) {
		%init(SokoPosterAddGestureForLocation);
	} else if ([editingSceneClass instancesRespondToSelector:@selector(_shouldAllowAddComplicationsTapGesture)]) {
		%init(SokoPosterAddGesture);
	}

	SokoDockGeometryObserve(^{
		[SokoPosterLayout relayoutAnimated:YES];
	});

	_dyld_register_func_for_add_image(SokoImageAdded);
}

%ctor {
	if ([SokoPosterModel isSupported]) %init(SokoPosterModel);

	if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
		SokoInitDock();
	} else {
		SokoInitPoster();
	}
}
