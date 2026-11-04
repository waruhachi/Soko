#import "SokoHookSupport.h"

%group SokoPosterAddGestureForLocation

%hook PREditingSceneViewController

- (BOOL)_shouldAllowAddComplicationsTapGestureForLocation:(long long)location {
	if (location != 0 || ![SokoPosterLayout usesBottomEditingRow]) return %orig;

	return SokoAllowsAddGestureOverRow(^{
		return %orig;
	});
}

%end

%end

void SokoPosterAddGestureForLocationInstallHooks(void) {
	%init(SokoPosterAddGestureForLocation);
}
