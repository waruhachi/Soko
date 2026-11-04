#import "SokoHookSupport.h"

%group SokoLiquidAssEditorDefaults

%hook LGClockEditorState

- (void)setController:(UIViewController *)controller {
	%orig;
	SokoLiquidAssPrepareEditorDefaults(controller);
}

%end

%hook PRPosterConfiguration

- (NSDictionary *)loadUserInfoWithError:(NSError **)error {
	NSError *loadError = nil;
	NSDictionary *info = %orig(&loadError);
	if (error) *error = loadError;
	return SokoLiquidAssEditorUserInfo(self, info, loadError);
}

%end

%end

void SokoLiquidAssEditorDefaultsInstallHooks(void) {
	%init(SokoLiquidAssEditorDefaults);
}
