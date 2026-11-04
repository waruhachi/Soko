#import "SokoHookSupport.h"

BOOL gActivePosterUsesBottomLayout;
__thread const void *gWallpaperDepthQuerySettings;
__thread const void *gEditorDepthQueryController;
__weak CSCoverSheetViewController *gCoverSheetViewController;

SokoDockCoordinator *SokoCoordinator(void) {
	CSCoverSheetViewController *coverSheet = gCoverSheetViewController;
	return coverSheet.isViewLoaded ? [SokoDockCoordinator coordinatorForCoverSheetViewController:coverSheet] : nil;
}

void SokoSetActivePosterUsesBottomLayout(BOOL usesBottomLayout) {
	SokoDockPublishActiveUsesBottomLayout(usesBottomLayout);
	if (usesBottomLayout == gActivePosterUsesBottomLayout) return;

	gActivePosterUsesBottomLayout = usesBottomLayout;
	[SokoCoordinator() setEnabled:usesBottomLayout];
}

void SokoRefreshDockSoon(void) {
	dispatch_async(dispatch_get_main_queue(), ^{
		[SokoCoordinator() refresh];
	});
}

void SokoPost(NSString *name, id object) {
	[[NSNotificationCenter defaultCenter] postNotificationName:name object:object];
}

BOOL SokoMoveFooter(UIView *footer, UIView *listView, CGFloat *movedCenterY) {
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

UIEdgeInsets SokoAdjustedFooterInsets(UIEdgeInsets insets, CSCombinedListViewController *combinedListViewController) {
	SokoNotificationList *notificationList = [SokoDockCoordinator activeCoordinator].notificationList;
	if (!notificationList) return insets;

	return [notificationList footerInsetsByAdjustingInsets:insets forCombinedListViewController:combinedListViewController];
}

BOOL SokoAllowsAddGestureOverRow(BOOL (^orig)(void)) {
	BOOL previous = [SokoPosterLayout isIgnoringGraphicComplications];
	[SokoPosterLayout setIgnoringGraphicComplications:YES];
	@try {
		return orig();
	}
	@finally {
		[SokoPosterLayout setIgnoringGraphicComplications:previous];
	}
}
