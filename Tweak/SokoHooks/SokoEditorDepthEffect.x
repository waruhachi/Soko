#import "SokoHookSupport.h"

static BOOL SokoEditorDepthEligible(PREditingSceneViewController *controller) {
	if (@available(iOS 18.0, *)) return YES;
	if (SokoLiquidAssClockEnabled()) return YES;

	// Before iOS 18, widgets stay visible over depth only while Soko's dock hosts the bottom row.
	return [SokoPosterLayout editingSceneViewControllerUsesBottomLayout:controller];
}

static BOOL SokoEditorDepthDisallowed(PREditingSceneViewController *controller) {
	if ([controller _shouldDepthEffectBeDisallowed]) return YES;

	id titleStyle = controller.configuredProperties.titleStyleConfiguration;
	return [titleStyle respondsToSelector:@selector(prefersVerticalTitleLayout)] &&
		[titleStyle prefersVerticalTitleLayout];
}

%group SokoEditorDepthEffect

%hook PREditingSceneViewController

- (BOOL)_shouldDepthEffectBeDisallowed {
	if (![SokoPosterLayout editingSceneViewControllerEditsLockScreen:self] || !SokoEditorDepthEligible(self)) return %orig;

	const void *previous = gEditorDepthQueryController;
	gEditorDepthQueryController = (__bridge const void *)self;
	@try {
		return %orig;
	}
	@finally {
		gEditorDepthQueryController = previous;
	}
}

- (void)viewDidLayoutSubviews {
	%orig;

	if (![SokoPosterLayout editingSceneViewControllerEditsLockScreen:self]) return;
	FBScene *scene = SokoIvarObject(self, "_scene");
	if (![scene respondsToSelector:@selector(updateSettingsWithBlock:)] || ![scene.settings respondsToSelector:@selector(pr_isDepthEffectDisallowed)]) return;

	BOOL disallowed = SokoEditorDepthDisallowed(self);
	if ([scene.settings pr_isDepthEffectDisallowed] == disallowed) return;
	[scene updateSettingsWithBlock:^(FBSMutableSceneSettings *settings) {
		[settings pr_setDepthEffectDisallowed:disallowed];
	}];
}

%end

%end

%group SokoEditorDepthEffectDisallowed

%hook PREditingSceneViewController

- (BOOL)_depthEffectDisallowed {
	BOOL disallowed = %orig;
	if (!disallowed || ![SokoPosterLayout editingSceneViewControllerEditsLockScreen:self]) return disallowed;

	return SokoEditorDepthDisallowed(self);
}

%end

%end

void SokoEditorDepthEffectInstallHooks(void) {
	%init(SokoEditorDepthEffect);
	if ([%c(PREditingSceneViewController) instancesRespondToSelector:@selector(_depthEffectDisallowed)]) {
		%init(SokoEditorDepthEffectDisallowed);
	}
}
