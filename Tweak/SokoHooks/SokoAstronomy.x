#import "SokoAstronomy.h"
#import "SokoHookSupport.h"

static __thread BOOL gAstronomyPositioningWithoutRow;
static NSMapTable<SokoAegirRenderingController *, id<SokoAstronomyEnvironmentSource>> *gAstronomyRenderers;
static NSMapTable<SokoAegirEditingController *, id<SokoAstronomyEnvironmentSource>> *gAstronomyEditors;
static NSHashTable<PREditorRootViewController *> *gAstronomyEditorRoots;

static CGRect SokoAstronomyBounds(id environment, CGRect (^original)(void)) {
	FBSSceneSettings *settings = SokoIvarObject(environment, "_settings");
	if (!settings || !SokoIsPortrait(settings.frame)) return original();
	BOOL bottom = [settings pr_usesEditingLayout] ? SokoEditorUsesBottomLayout() : SokoDockActiveUsesBottomLayout();
	if (!bottom || isnan(SokoDockGeometryBottomInset())) return original();

	// Only Astronomy's positioning bounds use the native no-top-row geometry.
	// The scene, widget hosts, and other environment queries keep their real state.
	BOOL previous = gAstronomyPositioningWithoutRow;
	gAstronomyPositioningWithoutRow = YES;
	@try {
		return original();
	}
	@finally {
		gAstronomyPositioningWithoutRow = previous;
	}
}

%group SokoAstronomy

%hook FBSSceneSettings

- (BOOL)pr_isComplicationRowConfigured {
	return gAstronomyPositioningWithoutRow ? NO : %orig;
}

%end

%hook PRPosterEnvironmentImpl

- (CGRect)contentCutoutBounds {
	return SokoAstronomyBounds(self, ^{
		return %orig;
	});
}

- (CGRect)floatingObscurableBounds {
	return SokoAstronomyBounds(self, ^{
		return %orig;
	});
}

%end

%hook SokoAegirRenderingController

- (void)renderer:(id)renderer didInitializeWithEnvironment:(id)environment {
	[gAstronomyRenderers setObject:renderer forKey:self];
	%orig;
}

- (void)renderer:(id)renderer didUpdateEnvironment:(id)environment withTransition:(id)transition {
	[gAstronomyRenderers setObject:renderer forKey:self];
	%orig;
}

- (void)rendererDidInvalidate:(id)renderer {
	[gAstronomyRenderers removeObjectForKey:self];
	%orig;
}

%end

%hook SokoAegirEditingController

- (void)editor:(id)editor didInitializeWithEnvironment:(id)environment {
	[gAstronomyEditors setObject:editor forKey:self];
	%orig;
}

- (void)editor:(id)editor didUpdateEnvironment:(id)environment withTransition:(id)transition {
	[gAstronomyEditors setObject:editor forKey:self];
	%orig;
}

- (void)editorDidInvalidate:(id)editor {
	[gAstronomyEditors removeObjectForKey:self];
	%orig;
}

%end

%end

%group SokoAstronomyReticle

%hook CSProminentLayoutController

- (CGRect)complicationRowElementEditingReticleFrameWithBoundingRect:(CGRect)rect {
	CGRect frame = %orig;
	if (CGRectIsNull(frame)) return frame;

	// Keep the row geometry used by Aegir intact; move only its editor reticle.
	CGRect stockRow = [self frameForElements:kSokoComplicationRowElement variant:kSokoEditingVariant withBoundingRect:rect];
	CGRect row = [SokoPosterLayout frameByAdjustingFrame:stockRow forElement:kSokoComplicationRowElement boundingRect:rect variant:kSokoEditingVariant layoutController:self];
	if (!CGRectIsNull(stockRow) && !CGRectIsNull(row)) frame.origin.y += CGRectGetMinY(row) - CGRectGetMinY(stockRow);
	return frame;
}

%end

%hook PREditorRootViewController

- (void)loadView {
	%orig;
	[gAstronomyEditorRoots addObject:self];
	[SokoEditorChrome registerReticleForEditorRootViewController:self];
}

%end

%end

void SokoAstronomyInstallHooks(void) {
	Class rendererClass = NSClassFromString(@"AegirPoster.AegirRenderingController") ?: NSClassFromString(@"_TtC11AegirPoster24AegirRenderingController");
	Class editorClass = NSClassFromString(@"AegirPoster.AegirEditingController") ?: NSClassFromString(@"_TtC11AegirPoster22AegirEditingController");
	Class environmentClass = NSClassFromString(@"PRPosterEnvironmentImpl");
	Class settingsClass = NSClassFromString(@"FBSSceneSettings");
	if (![rendererClass instancesRespondToSelector:@selector(renderer:didInitializeWithEnvironment:)] ||
		![rendererClass instancesRespondToSelector:@selector(renderer:didUpdateEnvironment:withTransition:)] ||
		![rendererClass instancesRespondToSelector:@selector(rendererDidInvalidate:)] ||
		![editorClass instancesRespondToSelector:@selector(editor:didInitializeWithEnvironment:)] ||
		![editorClass instancesRespondToSelector:@selector(editor:didUpdateEnvironment:withTransition:)] ||
		![editorClass instancesRespondToSelector:@selector(editorDidInvalidate:)] ||
		![environmentClass instancesRespondToSelector:@selector(contentCutoutBounds)] ||
		![environmentClass instancesRespondToSelector:@selector(floatingObscurableBounds)] ||
		![settingsClass instancesRespondToSelector:@selector(pr_usesEditingLayout)] ||
		![settingsClass instancesRespondToSelector:@selector(pr_isComplicationRowConfigured)] ||
		![settingsClass instancesRespondToSelector:@selector(frame)]) return;

	gAstronomyRenderers = [NSMapTable weakToWeakObjectsMapTable];
	gAstronomyEditors = [NSMapTable weakToWeakObjectsMapTable];
	SokoDockGeometryReload();
	%init(SokoAstronomy, SokoAegirRenderingController = rendererClass, SokoAegirEditingController = editorClass);

	Class layoutClass = NSClassFromString(@"CSProminentLayoutController");
	Class rootClass = NSClassFromString(@"PREditorRootViewController");
	if ([layoutClass instancesRespondToSelector:@selector(complicationRowElementEditingReticleFrameWithBoundingRect:)] &&
		[layoutClass instancesRespondToSelector:@selector(frameForElements:variant:withBoundingRect:)] &&
		[layoutClass respondsToSelector:@selector(frameForElements:variant:)] &&
		[rootClass instancesRespondToSelector:@selector(graphicComplicationsReticleView)]) {
		gAstronomyEditorRoots = [NSHashTable weakObjectsHashTable];
		%init(SokoAstronomyReticle);
	}

	SokoDockGeometryObserve(^{
		for (PREditorRootViewController *root in gAstronomyEditorRoots.allObjects) {
			[SokoEditorChrome updateReticleForEditorRootViewController:root];
		}
		// These native callbacks recalculate the crop from the current environment.
		// Aegir's 16.3.1 implementations do not consume the transition argument.
		for (SokoAegirRenderingController *controller in gAstronomyRenderers.keyEnumerator.allObjects) {
			id<SokoAstronomyEnvironmentSource> renderer = [gAstronomyRenderers objectForKey:controller];
			id environment = renderer.environment;
			if (environment) [controller renderer:renderer didUpdateEnvironment:environment withTransition:nil];
		}
		for (SokoAegirEditingController *controller in gAstronomyEditors.keyEnumerator.allObjects) {
			id<SokoAstronomyEnvironmentSource> editor = [gAstronomyEditors objectForKey:controller];
			id environment = editor.environment;
			if (environment) [controller editor:editor didUpdateEnvironment:environment withTransition:nil];
		}
	});
}
