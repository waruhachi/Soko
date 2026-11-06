#import "SokoHookSupport.h"

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

void SokoDockInstallHooks(void) {
	%init(SokoDock);
}

%group SokoDockListFooter

%hook NCNotificationListView

- (void)_layoutOverlayFooterViewIfNecessary {
	%orig;

	SokoMoveFooter(self.overlayFooterView, self, NULL);
}

- (void)setFrame:(CGRect)frame {
	%orig;

	CGRect restoredFrame;
	if (![[SokoDockCoordinator activeCoordinator].notificationList getRestoredFrame:&restoredFrame forListView:self]) return;

	void (*setScrollViewFrame)(id, SEL, CGRect) = (void (*)(id, SEL, CGRect))[UIScrollView instanceMethodForSelector:_cmd];
	setScrollViewFrame(self, _cmd, restoredFrame);
	if (self.hasPerformedFirstLayout) [self layoutIfNeeded];
}

%end

%end

void SokoDockListFooterInstallHooks(void) {
	%init(SokoDockListFooter);
}

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

void SokoDockContainerFooterInstallHooks(void) {
	%init(SokoDockContainerFooter);
}

%group SokoDockWidgetDescriptors

%hook CSComplicationContainerViewController

- (void)setWidgetDescriptors:(NSArray *)widgetDescriptors {
	%orig;

	SokoRefreshDockSoon();
}

%end

%end

void SokoDockWidgetDescriptorsInstallHooks(void) {
	%init(SokoDockWidgetDescriptors);
}

%group SokoDockWidgetGrid

%hook CSWidgetGridViewController

- (void)setComplicationDescriptors:(NSArray *)complicationDescriptors iconLayout:(id)iconLayout {
	%orig;

	SokoRefreshDockSoon();
}

%end

%end

void SokoDockWidgetGridInstallHooks(void) {
	%init(SokoDockWidgetGrid);
}

%group SokoDockFooterInsets

%hook CSCombinedListViewController

- (UIEdgeInsets)notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:(id)structuredListViewController {
	UIEdgeInsets insets = %orig;

	return SokoAdjustedFooterInsets(insets, self);
}

%end

%end

void SokoDockFooterInsetsInstallHooks(void) {
	%init(SokoDockFooterInsets);
}
