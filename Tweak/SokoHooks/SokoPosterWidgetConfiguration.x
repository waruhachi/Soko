#import "SokoHookSupport.h"

%group SokoPosterWidgetConfiguration

%hook PREditingSceneViewController

- (void)setPresentedWidgetConfigurationViewController:(UIViewController *)controller {
	%orig;

	[SokoPosterLayout editingSceneViewControllerDidChangePresentation:self];
}

%end

%end

void SokoPosterWidgetConfigurationInstallHooks(void) {
	%init(SokoPosterWidgetConfiguration);
}
