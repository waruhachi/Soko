#import "../SokoCompatibility/SokoCompatibility.h"
#import "SokoPosterLayout.h"

@interface SokoEditorChrome : NSObject
+ (void)registerEditorRootViewController:(PREditorRootViewController *)controller;
+ (void)registerReticleForEditorRootViewController:(PREditorRootViewController *)controller;
+ (void)updateReticleForEditorRootViewController:(PREditorRootViewController *)controller;
+ (void)update;
@end
