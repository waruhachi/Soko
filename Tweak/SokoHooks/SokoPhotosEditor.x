#import "SokoHookSupport.h"

%group SokoPhotosEditor

%hook PUWallpaperPosterEditorController

- (BOOL)_createHintLabelIfNeeded {
	BOOL created = %orig;

	self.hintLabel.hidden = YES;
	return created;
}

- (void)_updateHintLabelAnimated:(BOOL)animated {
	%orig;

	self.hintLabel.hidden = YES;
}

%end

%end

void SokoPhotosEditorInstallHooks(void) {
	%init(SokoPhotosEditor);
}
