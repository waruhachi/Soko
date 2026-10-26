#import "../SokoCompatibility/SokoCompatibility.h"
#import "SokoPosterLayout.h"

@interface SokoEditorChrome : NSObject
+ (void)registerEditorRootViewController:(PREditorRootViewController *)controller;
+ (void)update;
@end
