#import "SokoNotificationList.h"

static const CGFloat kSokoListFooterPadding = 20.0;
static const CGFloat kSokoNotificationToDockSpacing = 10.0;

@interface SokoNotificationList ()
@property (nonatomic, weak) CSCoverSheetViewController *coverSheetViewController;
@property (nonatomic, weak) id<SokoNotificationListDock> dock;
@property (nonatomic, weak) UIView *adjustedListView;
@property (nonatomic) UIEdgeInsets originalInsets;
@property (nonatomic) CGFloat footerCenterDistanceFromListBottom;
@property (nonatomic) double appliedListMinYAdjustment;
@end

@implementation SokoNotificationList

- (instancetype)initWithCoverSheetViewController:(CSCoverSheetViewController *)coverSheetViewController dock:(id<SokoNotificationListDock>)dock {
	self = [super init];
	if (self) {
		_coverSheetViewController = coverSheetViewController;
		_dock = dock;
		_footerCenterDistanceFromListBottom = NAN;
	}
	return self;
}

- (CSCombinedListViewController *)combinedListViewController {
	return self.coverSheetViewController.mainPageContentViewController.combinedListViewController;
}

- (NCNotificationStructuredListViewController *)structuredListViewControllerForCombinedListViewController:(CSCombinedListViewController *)combinedListViewController {
	return SokoIvarObject(combinedListViewController, "_structuredListViewController");
}

- (UIScrollView *)listViewForStructuredListViewController:(NCNotificationStructuredListViewController *)structured {
	UIScrollView *list = [structured respondsToSelector:@selector(masterListView)] ? structured.masterListView : nil;
	if (!list && [structured respondsToSelector:@selector(scrollView)]) list = structured.scrollView;

	return list;
}

- (NCNotificationMasterList *)listModelForStructuredListViewController:(NCNotificationStructuredListViewController *)structured {
	NCNotificationMasterList *model = [structured respondsToSelector:@selector(masterList)] ? structured.masterList : nil;
	if (!model && [structured respondsToSelector:@selector(listModel)]) model = structured.listModel;

	return model;
}

- (NCNotificationStructuredListView *)containerForStructuredListViewController:(NCNotificationStructuredListViewController *)structured {
	if (![structured respondsToSelector:@selector(_updateListEdgeInsetsForSize:)]) return nil;

	NCNotificationStructuredListView *container = (NCNotificationStructuredListView *)structured.viewIfLoaded;
	return [container respondsToSelector:@selector(footerInsets)] ? container : nil;
}

- (double)listMinYByAdjustingListMinY:(double)listMinY {
	if (!self.dock.dockVisible) return listMinY;

	return MAX(0.0, listMinY - self.dock.complicationContainerHeight);
}

- (UIEdgeInsets)footerInsetsByAdjustingInsets:(UIEdgeInsets)insets forCombinedListViewController:(CSCombinedListViewController *)combinedListViewController {
	self.originalInsets = insets;
	if (!self.dock.dockVisible) return insets;

	NCNotificationStructuredListViewController *structured = [self structuredListViewControllerForCombinedListViewController:combinedListViewController];
	UIScrollView *list = [self listViewForStructuredListViewController:structured];
	UIView *dockContainer = self.dock.dockContainerView;
	if (!list.superview || !dockContainer) return insets;

	CGFloat dockTop = [dockContainer convertPoint:CGPointMake(0.0, self.dock.dockTopY) toView:list.superview].y;
	CGFloat margin = CGRectGetMaxY(list.frame) - dockTop + kSokoNotificationToDockSpacing;

	if ([self containerForStructuredListViewController:structured]) {
		CGFloat shift = MAX(0.0, margin - kSokoListFooterPadding - insets.top);
		insets.top += shift;
		insets.bottom += shift;
		return insets;
	}

	insets.top = MAX(insets.top, margin - kSokoListFooterPadding);
	insets.bottom = MAX(insets.bottom, margin);
	return insets;
}

- (UIEdgeInsets)requestedInsetsForCombinedListViewController:(CSCombinedListViewController *)combined structuredListViewController:(NCNotificationStructuredListViewController *)structured {
	if ([combined respondsToSelector:@selector(notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:forOrientation:)]) {
		long long orientation = SokoIsPortrait(combined.viewIfLoaded.bounds) ? 1 : 3;
		return [combined notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:structured forOrientation:orientation];
	}

	return [combined notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:structured];
}

- (BOOL)getFooterCenterY:(CGFloat *)centerY forListView:(UIView *)listView {
	if (!listView) return NO;

	BOOL adjusted = listView == self.adjustedListView;
	if (!adjusted && !self.dock.dockVisible) return NO;

	CGFloat y;
	CGFloat distance = [self footerCenterDistanceFromBottomOfListView:listView];
	if (!isnan(distance)) {
		y = CGRectGetMaxY(listView.bounds) - distance;
	} else if (adjusted) {
		CGRect visibleRect = [listView respondsToSelector:@selector(visibleRect)] ? ((NCNotificationListView *)listView).visibleRect : listView.bounds;
		y = CGRectGetMaxY(visibleRect) - (self.originalInsets.top + self.originalInsets.bottom) / 2.0;
	} else {
		return NO;
	}

	if (centerY) *centerY = y;
	return YES;
}

- (CGFloat)footerCenterDistanceFromBottomOfListView:(UIView *)listView {
	CSCoverSheetView *coverSheetView = (CSCoverSheetView *)self.coverSheetViewController.viewIfLoaded;
	CGFloat buttonCenterY;
	if (!coverSheetView || !SokoQuickActionButtonCenterY(coverSheetView, &buttonCenterY)) return self.footerCenterDistanceFromListBottom;

	CGFloat offset = 0.0;
	UIView *view = listView;
	for (; view && view != coverSheetView; view = view.superview) {
		CGFloat originY = view.center.y - CGRectGetHeight(view.bounds) * view.layer.anchorPoint.y;
		offset += originY - view.bounds.origin.y;
	}

	CGFloat targetY;
	if (view == coverSheetView) {
		targetY = buttonCenterY - offset;
	} else {
		targetY = [listView convertPoint:CGPointMake(0.0, buttonCenterY) fromView:coverSheetView].y;
	}

	self.footerCenterDistanceFromListBottom = CGRectGetMaxY(listView.bounds) - targetY;
	return self.footerCenterDistanceFromListBottom;
}

- (void)updateLayout {
	CSCombinedListViewController *combined = [self combinedListViewController];
	NCNotificationStructuredListViewController *structured = [self structuredListViewControllerForCombinedListViewController:combined];
	UIScrollView *list = [self listViewForStructuredListViewController:structured];
	NCNotificationStructuredListView *container = [self containerForStructuredListViewController:structured];

	BOOL changed = NO;
	if (list && container && [combined respondsToSelector:@selector(notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:forOrientation:)]) {
		changed = [self updateContainer:container list:list combinedListViewController:combined structuredListViewController:structured];
	} else if (list && structured && [self canUpdateListView:list combinedListViewController:combined]) {
		changed = [self updateListView:(NCNotificationListView *)list combinedListViewController:combined structuredListViewController:structured];
	} else {
		self.adjustedListView = nil;
	}

	changed = [self updateListMinYForCombinedListViewController:combined] || changed;
	if (changed) [self refreshVisibleRectForList:list container:container structuredListViewController:structured];
}

- (BOOL)canUpdateListView:(UIScrollView *)list combinedListViewController:(CSCombinedListViewController *)combined {
	BOOL asksForInsets = [combined respondsToSelector:@selector(notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:forOrientation:)] ||
		[combined respondsToSelector:@selector(notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:)];
	BOOL hasInsets = [list respondsToSelector:@selector(overlayFooterViewEdgeInsets)] &&
		[list respondsToSelector:@selector(setOverlayFooterViewEdgeInsets:)];

	return asksForInsets && hasInsets;
}

- (BOOL)updateContainer:(NCNotificationStructuredListView *)container list:(UIScrollView *)list combinedListViewController:(CSCombinedListViewController *)combined structuredListViewController:(NCNotificationStructuredListViewController *)structured {
	UIEdgeInsets insets = [self requestedInsetsForCombinedListViewController:combined structuredListViewController:structured];
	self.adjustedListView = UIEdgeInsetsEqualToEdgeInsets(insets, self.originalInsets) ? nil : container;
	if (UIEdgeInsetsEqualToEdgeInsets(insets, container.footerInsets)) return NO;

	[structured _updateListEdgeInsetsForSize:list.frame.size];
	[container setNeedsLayout];
	return YES;
}

- (BOOL)updateListView:(NCNotificationListView *)list combinedListViewController:(CSCombinedListViewController *)combined structuredListViewController:(NCNotificationStructuredListViewController *)structured {
	UIEdgeInsets insets = [self requestedInsetsForCombinedListViewController:combined structuredListViewController:structured];
	self.adjustedListView = UIEdgeInsetsEqualToEdgeInsets(insets, self.originalInsets) ? nil : list;
	if (UIEdgeInsetsEqualToEdgeInsets(insets, list.overlayFooterViewEdgeInsets)) return NO;

	list.overlayFooterViewEdgeInsets = insets;
	[list setNeedsLayout];
	return YES;
}

- (BOOL)updateListMinYForCombinedListViewController:(CSCombinedListViewController *)combined {
	double adjustment = self.dock.dockVisible ? self.dock.complicationContainerHeight : 0.0;
	if (fabs(adjustment - self.appliedListMinYAdjustment) <= 0.5 || ![combined respondsToSelector:@selector(layoutListView)]) return NO;

	self.appliedListMinYAdjustment = adjustment;
	[combined layoutListView];
	return YES;
}

- (void)refreshVisibleRectForList:(UIScrollView *)list container:(UIView *)container structuredListViewController:(NCNotificationStructuredListViewController *)structured {
	NCNotificationMasterList *model = [self listModelForStructuredListViewController:structured];

	if ([model respondsToSelector:@selector(updateListViewVisibleRectForSize:)]) {
		[model updateListViewVisibleRectForSize:list.frame.size];
		[list layoutIfNeeded];
		[container layoutIfNeeded];

		BOOL historyRevealed = [model respondsToSelector:@selector(isNotificationHistoryRevealed)] && [model isNotificationHistoryRevealed];
		BOOL canSnap = container && [model respondsToSelector:@selector(_scrollToSystemPreferredPageTypeIfPossible)];
		if (canSnap && !historyRevealed && !list.tracking && !list.decelerating) [model _scrollToSystemPreferredPageTypeIfPossible];
	} else if ([model respondsToSelector:@selector(updateListViewVisibleRect)]) {
		[model updateListViewVisibleRect];
		[list layoutIfNeeded];
	}
}

@end
