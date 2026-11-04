#import "SokoHookSupport.h"

@interface PREditingSceneViewController (SokoDepthEffect)
@property (nonatomic, strong) NSNumber *soko_bottomDepthRow;
@end

static void SokoRefreshEditorDepth(PREditingSceneViewController *controller) {
	BOOL bottom = [SokoPosterLayout editingSceneViewControllerHasBottomWidgetRow:controller];
	NSNumber *previous = controller.soko_bottomDepthRow;
	if (previous && previous.boolValue == bottom) return;
	// Record before publishing; a native scene update can request layout again.
	controller.soko_bottomDepthRow = @(bottom);
	[controller _updateSceneSettingsForDepthEffectDisallowed];
}

%group SokoEditorDepthEffect

%hook PREditingSceneViewController

%property(nonatomic, strong) NSNumber *soko_bottomDepthRow;

- (BOOL)_shouldDepthEffectBeDisallowed {
	if (![SokoPosterLayout editingSceneViewControllerHasBottomWidgetRow:self]) return %orig;

	// Keep native variant, focus, and provider restrictions. Only the widget
	// presence check made by this controller's depth predicate is suppressed.
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
	SokoRefreshEditorDepth(self);
}

%end

%hook PRComplicationContainerViewController

- (void)viewDidLayoutSubviews {
	%orig;
	// LiquidAss lays out its row independently of the editing scene's view.
	for (UIViewController *parent = self.parentViewController; parent; parent = parent.parentViewController) {
		if (![parent isKindOfClass:%c(PREditingSceneViewController)]) continue;
		SokoRefreshEditorDepth((PREditingSceneViewController *)parent);
		break;
	}
}

%end

%end

void SokoEditorDepthEffectInstallHooks(void) {
	%init(SokoEditorDepthEffect);
}
