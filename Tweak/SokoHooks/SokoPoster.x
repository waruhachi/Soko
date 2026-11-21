#import "SokoHookSupport.h"

static BOOL SokoEventBeginsTouch(UIEvent *event) {
	if (event.type != UIEventTypeTouches) return NO;

	for (UITouch *touch in event.allTouches) {
		if (touch.phase == UITouchPhaseBegan) return YES;
	}
	return NO;
}

%group SokoPoster

%hook UIApplication

- (void)sendEvent:(UIEvent *)event {
	// Poster scene windows can appear after the editor loads; attach before the first touch is dispatched.
	if (SokoEventBeginsTouch(event)) [SokoLayoutSwipeHandler attachSwipesToAllWindows];
	%orig;
}

%end

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

- (void)viewDidAppear:(BOOL)animated {
	%orig;

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

- (void)viewDidAppear:(BOOL)animated {
	%orig;

	if ([SokoPosterLayout editingSceneViewControllerEditsLockScreen:self]) [SokoLayoutSwipeHandler installOnEditingSceneViewController:self];
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

	// Row swipes land in the poster extension, which forwards them here as layout requests.
	SokoEditorObserveLayoutRequests(^(BOOL usesBottomLayout) {
		for (PREditingSceneViewController *controller in [SokoPosterLayout editingSceneViewControllers]) {
			if (![SokoPosterLayout canSwipeEditingSceneViewController:controller]) continue;
			[SokoPosterLayout setUsesBottomLayout:usesBottomLayout forEditingSceneViewController:controller];
			break;
		}
	});
}
