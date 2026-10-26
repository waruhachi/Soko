#import "../SokoRuntime/SokoRuntime.h"
#import "SokoQuickActions.h"

@protocol SokoNotificationListDock <NSObject>
@property (nonatomic, readonly) BOOL dockVisible;
@property (nonatomic, readonly) CGFloat dockTopY;
@property (nonatomic, readonly) UIView *dockContainerView;
@property (nonatomic, readonly) double complicationContainerHeight;
@end

@interface SokoNotificationList : NSObject
- (instancetype)initWithCoverSheetViewController:(CSCoverSheetViewController *)coverSheetViewController dock:(id<SokoNotificationListDock>)dock;

- (void)updateLayout;
- (double)listMinYByAdjustingListMinY:(double)listMinY;
- (UIEdgeInsets)footerInsetsByAdjustingInsets:(UIEdgeInsets)insets forCombinedListViewController:(CSCombinedListViewController *)combinedListViewController;
- (BOOL)getFooterCenterY:(CGFloat *)centerY forListView:(UIView *)listView;
@end
