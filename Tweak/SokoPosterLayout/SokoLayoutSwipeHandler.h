#import "SokoPosterLayout.h"

@interface SokoLayoutSwipeHandler : NSObject <UIGestureRecognizerDelegate>
+ (void)installOnEditingSceneViewController:(PREditingSceneViewController *)controller;
+ (void)installOnComplicationContainerViewController:(UIViewController *)controller;
@end
