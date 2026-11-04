#import "SokoHookSupport.h"

%group SokoPosterAddGesture

%hook PREditingSceneViewController

- (BOOL)_shouldAllowAddComplicationsTapGesture {
	if (![SokoPosterLayout usesBottomEditingRow]) return %orig;

	return SokoAllowsAddGestureOverRow(^{
		return %orig;
	});
}

%end

%end

void SokoPosterAddGestureInstallHooks(void) {
	%init(SokoPosterAddGesture);
}
