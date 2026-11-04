#import <Foundation/Foundation.h>
#import <dlfcn.h>

#import "../SokoRuntime/SokoPrivate.h"

FOUNDATION_EXPORT BOOL SokoLiquidAssClockEnabled(void);
FOUNDATION_EXPORT NSDictionary *SokoLiquidAssUserInfoForConfiguration(id configuration);
FOUNDATION_EXPORT BOOL SokoLiquidAssUserInfoUsesBottomLayout(NSDictionary *userInfo);
FOUNDATION_EXPORT void SokoLiquidAssPrepareEditorDefaults(UIViewController *controller);
FOUNDATION_EXPORT NSDictionary *SokoLiquidAssEditorUserInfo(id configuration, NSDictionary *info, NSError *error);
