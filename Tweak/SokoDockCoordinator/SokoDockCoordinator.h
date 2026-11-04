#import "../SokoDockGeometry/SokoDockGeometry.h"
#import "../SokoRuntime/SokoRuntime.h"
#import "SokoNotificationList.h"
#import "SokoQuickActions.h"

FOUNDATION_EXPORT NSString *const SokoProminentDisplayVibrancyDidChangeNotification;
FOUNDATION_EXPORT NSString *const SokoProminentDisplayContentAlphaDidChangeNotification;

@interface SokoDockCoordinator : NSObject <SokoNotificationListDock>
@property (nonatomic, readonly) SokoNotificationList *notificationList;
@property (nonatomic, readonly) BOOL allowsWallpaperDepthEffect;

+ (BOOL)isSupported;
+ (instancetype)coordinatorForCoverSheetViewController:(CSCoverSheetViewController *)controller;
+ (instancetype)coordinatorForCoverSheetView:(UIView *)view;
+ (instancetype)activeCoordinator;

- (void)setEnabled:(BOOL)enabled;
- (void)refresh;
- (void)coverSheetViewDidLayout;
- (void)registerWallpaperDepthScene:(FBScene *)scene forReplica:(UIView *)replica;
- (void)prepareWallpaperDepthScene:(FBScene *)scene settings:(FBSMutableSceneSettings *)settings;
@end
