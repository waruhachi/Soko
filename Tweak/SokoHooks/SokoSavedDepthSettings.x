#import "SokoHookSupport.h"

%group SokoSavedDepthSettings

%hook PBUIPosterViewController

- (void)scene:(FBScene *)scene willUpdateSettings:(FBSMutableSceneSettings *)settings withTransitionContext:(id)context {
	%orig;
	if (scene == SokoIvarObject(self, "_scene")) {
		[SokoCoordinator() prepareWallpaperDepthScene:scene settings:settings];
	}
}

%end

%end

void SokoSavedDepthSettingsInstallHooks(void) {
	%init(SokoSavedDepthSettings);
}
