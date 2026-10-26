#import "../SokoDockGeometry/SokoDockGeometry.h"
#import "../SokoRuntime/SokoRuntime.h"
#import "SokoNotificationList.h"
#import "SokoQuickActions.h"

FOUNDATION_EXPORT NSString *const SokoProminentDisplayVibrancyDidChangeNotification;
FOUNDATION_EXPORT NSString *const SokoProminentDisplayContentAlphaDidChangeNotification;

@interface SokoDockCoordinator : NSObject <SokoNotificationListDock>
@property (nonatomic, readonly) SokoNotificationList *notificationList;

+ (BOOL)isSupported;
+ (instancetype)coordinatorForCoverSheetViewController:(CSCoverSheetViewController *)controller;
+ (instancetype)coordinatorForCoverSheetView:(UIView *)view;
+ (instancetype)activeCoordinator;

- (void)setEnabled:(BOOL)enabled;
- (void)refresh;
- (void)coverSheetViewDidLayout;
@end
