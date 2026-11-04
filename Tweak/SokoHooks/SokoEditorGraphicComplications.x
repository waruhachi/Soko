#import "SokoHookSupport.h"

%group SokoEditorGraphicComplications

%hook PREditingSceneViewController

- (BOOL)_hasGraphicComplications {
	if (gEditorDepthQueryController == (__bridge const void *)self || [SokoPosterLayout isIgnoringGraphicComplications]) return NO;
	return %orig;
}

%end

%end

void SokoEditorGraphicComplicationsInstallHooks(void) {
	%init(SokoEditorGraphicComplications);
}
