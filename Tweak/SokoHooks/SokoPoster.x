#import "SokoHookSupport.h"

%group SokoPoster

%hook CSProminentLayoutController

- (CGRect)_frameForElement:(unsigned long long)element withBoundingRect:(CGRect)rect variant:(unsigned long long)variant {
	CGRect frame = %orig;

	return [SokoPosterLayout frameByAdjustingFrame:frame forElement:element boundingRect:rect variant:variant layoutController:self];
}

- (CGRect)complicationRowElementEditingReticleFrameWithBoundingRect:(CGRect)rect {
	CGRect frame = %orig;

	return [SokoPosterLayout reticleFrameByAdjustingFrame:frame layoutController:self boundingRect:rect];
}

%end

%hook PRComplicationContainerViewController

- (void)viewDidLoad {
	%orig;

	[SokoPosterLayout registerComplicationContainerViewController:self];
	[SokoLayoutSwipeHandler installOnComplicationContainerViewController:self];
}

%end

%hook PREditorRootViewController

- (void)loadView {
	%orig;

	[SokoEditorChrome registerEditorRootViewController:self];
}

%end

%hook PREditingSceneViewController

- (instancetype)initWithProvider:(id)provider contents:(id)contents configurableOptions:(id)configurableOptions configuredProperties:(PRPosterConfiguredProperties *)configuredProperties additionalInfo:(id)additionalInfo {
	self = %orig;

	if (self) [SokoPosterLayout setInitialComplicationLayout:configuredProperties.complicationLayout forEditingSceneViewController:self];
	return self;
}

- (void)viewDidLoad {
	%orig;

	if ([SokoPosterLayout registerEditingSceneViewController:self]) [SokoLayoutSwipeHandler installOnEditingSceneViewController:self];
}

- (void)setPresentedComplicationsGallery:(UINavigationController *)gallery {
	%orig;

	[SokoPosterLayout editingSceneViewControllerDidChangePresentation:self];
}

- (void)setPresentedInlineComplicationsGallery:(UINavigationController *)gallery {
	%orig;

	[SokoPosterLayout editingSceneViewControllerDidChangePresentation:self];
}

%end

%hook PREditor

- (void)setCoveredByHostModalPresentation:(BOOL)covered {
	%orig;

	[SokoPosterLayout setCoveredByHostModalPresentation:covered];
}

%end

%end

void SokoPosterInstallHooks(void) {
	%init(SokoPoster);
}
