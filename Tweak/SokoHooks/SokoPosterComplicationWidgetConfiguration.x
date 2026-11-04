#import "SokoHookSupport.h"

%group SokoPosterComplicationWidgetConfiguration

%hook PREditingSceneViewController

- (void)setPresentedComplicationWidgetConfigurationViewController:(UIViewController *)controller {
	%orig;

	[SokoPosterLayout editingSceneViewControllerDidChangePresentation:self];
}

- (void)setPresentedControlsGallery:(UIViewController *)gallery {
	%orig;

	[SokoPosterLayout editingSceneViewControllerDidChangePresentation:self];
}

- (void)setPresentedControlWidgetConfigurationViewController:(UIViewController *)controller {
	%orig;

	[SokoPosterLayout editingSceneViewControllerDidChangePresentation:self];
}

%end

%end

void SokoPosterComplicationWidgetConfigurationInstallHooks(void) {
	%init(SokoPosterComplicationWidgetConfiguration);
}
