#import "SokoHookSupport.h"

%group SokoSavedDepthEffect

%hook FBSSceneSettings

- (BOOL)pr_isDepthEffectDisallowed {
	return gWallpaperDepthQuerySettings == (__bridge const void *)self ? NO : %orig;
}

%end

%hook PBUIPosterLockViewController

- (id)portalSourceForReplicaView:(UIView *)replica {
	NSString *reason = SokoIvarObject(replica, "_reason");
	if (![SokoCoordinator() allowsWallpaperDepthEffect] ||
		![reason isKindOfClass:[NSString class]] || ![reason isEqualToString:@"CSCoverSheetViewController"]) return %orig;

	FBScene *scene = SokoIvarObject(self, "_scene");
	FBSSceneSettings *settings = [scene respondsToSelector:@selector(settings)] ? scene.settings : nil;
	if (!settings) return %orig;
	[SokoCoordinator() registerWallpaperDepthScene:scene forReplica:replica];

	// Resolve the native source while the scene correction is being published.
	// The renderer's separate depth preference remains intact.
	const void *previous = gWallpaperDepthQuerySettings;
	gWallpaperDepthQuerySettings = (__bridge const void *)settings;
	@try {
		return %orig;
	}
	@finally {
		gWallpaperDepthQuerySettings = previous;
	}
}

%end

%end

void SokoSavedDepthEffectInstallHooks(void) {
	%init(SokoSavedDepthEffect);
}
