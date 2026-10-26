#import "SokoEditorChrome.h"

static const CGFloat kSokoBottomRowEditingOffset = 28.0;

static const void *kSokoEditorBottomLayoutKey = &kSokoEditorBottomLayoutKey;

static NSHashTable<UIViewController *> *gComplicationContainerViewControllers;
static NSHashTable<PREditingSceneViewController *> *gEditingSceneViewControllers;

static __thread BOOL gComputingStockLayout;
static BOOL gIgnoringGraphicComplications;

static __weak PREditingSceneViewController *gDodgingEditingSceneViewController;
static BOOL gCoveredByHostModalPresentation;

static NSHashTable *SokoRegister(NSHashTable *table, id object) {
	if (!table) table = [NSHashTable weakObjectsHashTable];

	[table addObject:object];
	return table;
}

@implementation SokoPosterLayout

+ (BOOL)isSupported {
	Class containerClass = NSClassFromString(@"PRComplicationContainerViewController");
	if ([containerClass instancesRespondToSelector:NSSelectorFromString(@"setWidgetsUseBottomLayout:")]) return NO;

	Class layoutClass = NSClassFromString(@"CSProminentLayoutController");
	return [layoutClass instancesRespondToSelector:@selector(_frameForElement:withBoundingRect:variant:)] &&
		[layoutClass instancesRespondToSelector:@selector(complicationRowElementEditingReticleFrameWithBoundingRect:)] &&
		[layoutClass instancesRespondToSelector:@selector(frameForElements:variant:withBoundingRect:)] &&
		[layoutClass respondsToSelector:@selector(frameForElements:variant:)];
}

+ (BOOL)layoutControllerUsesBottomLayout:(CSProminentLayoutController *)layoutController {
	static Class cellClass;
	static Ivar layoutIvar;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cellClass = NSClassFromString(@"_TtC11PosterBoard34LockScreenPosterCollectionViewCell");
		layoutIvar = cellClass ? class_getInstanceVariable(cellClass, "complicationLayout") : NULL;
	});

	id environment = [layoutController respondsToSelector:@selector(traitEnvironment)] ? layoutController.traitEnvironment : nil;
	UIView *view = [environment isKindOfClass:[UIViewController class]] ? ((UIViewController *)environment).viewIfLoaded : environment;
	if (![view isKindOfClass:[UIView class]]) view = nil;

	for (; cellClass && view; view = view.superview) {
		if (![view isKindOfClass:cellClass]) continue;

		return layoutIvar && [SokoPosterModel complicationLayoutUsesBottomLayout:object_getIvar(view, layoutIvar)];
	}

	return SokoDockActiveUsesBottomLayout();
}

+ (CGRect)frameByAdjustingFrame:(CGRect)frame forElement:(unsigned long long)element boundingRect:(CGRect)boundingRect variant:(unsigned long long)variant layoutController:(CSProminentLayoutController *)layoutController {
	if (element != kSokoComplicationRowElement || variant == kSokoReticleVariant || gComputingStockLayout) return frame;

	BOOL editing = variant == kSokoEditingVariant;
	BOOL bottom = editing ? [self usesBottomEditingRow] : [self layoutControllerUsesBottomLayout:layoutController];
	if (!bottom) return frame;

	CGFloat inset = SokoDockGeometryBottomInset();
	if (isnan(inset) || CGRectIsNull(frame) || CGRectGetHeight(frame) <= 0.0 || !SokoIsPortrait(boundingRect)) return frame;

	frame.origin.y = CGRectGetMaxY(boundingRect) - inset - CGRectGetHeight(frame);
	if (editing) frame.origin.y -= kSokoBottomRowEditingOffset;
	return frame;
}

+ (CGRect)reticleFrameByAdjustingFrame:(CGRect)frame layoutController:(CSProminentLayoutController *)layoutController boundingRect:(CGRect)boundingRect {
	if (gComputingStockLayout || CGRectIsNull(frame)) return frame;

	CGRect row = [layoutController frameForElements:kSokoComplicationRowElement variant:kSokoEditingVariant withBoundingRect:boundingRect];

	gComputingStockLayout = YES;
	CGRect stockRow = [layoutController frameForElements:kSokoComplicationRowElement variant:kSokoEditingVariant withBoundingRect:boundingRect];
	gComputingStockLayout = NO;

	if (CGRectIsNull(row) || CGRectIsNull(stockRow)) return frame;

	frame.origin.y += CGRectGetMinY(row) - CGRectGetMinY(stockRow);
	return frame;
}

+ (CGRect)editingRowFrame {
	Class layoutClass = NSClassFromString(@"CSProminentLayoutController");
	return [layoutClass frameForElements:kSokoComplicationRowElement variant:kSokoEditingVariant];
}

+ (void)registerComplicationContainerViewController:(UIViewController *)controller {
	gComplicationContainerViewControllers = SokoRegister(gComplicationContainerViewControllers, controller);
}

+ (BOOL)editingSceneViewControllerEditsLockScreen:(PREditingSceneViewController *)controller {
	if (![controller respondsToSelector:@selector(posterRole)]) return YES;

	NSString *role = controller.posterRole;
	return [role isKindOfClass:[NSString class]] && [role isEqualToString:@"PRPosterRoleLockScreen"];
}

+ (BOOL)registerEditingSceneViewController:(PREditingSceneViewController *)controller {
	if (![self editingSceneViewControllerEditsLockScreen:controller]) return NO;

	gEditingSceneViewControllers = SokoRegister(gEditingSceneViewControllers, controller);
	SokoEditorPublishUsesBottomLayout([self editingSceneViewControllerUsesBottomLayout:controller]);
	[self relayoutAnimated:NO];
	return YES;
}

+ (NSArray<PREditingSceneViewController *> *)editingSceneViewControllers {
	return gEditingSceneViewControllers.allObjects ?: @[];
}

+ (PREditingSceneViewController *)editingSceneViewControllerForComplicationContainerViewController:(UIViewController *)container {
	if (!container) return nil;

	PREditingSceneViewController *candidate = nil;
	for (PREditingSceneViewController *controller in gEditingSceneViewControllers.allObjects) {
		NSArray *containers = [controller respondsToSelector:@selector(complicationContainerViewControllers)] ? controller.complicationContainerViewControllers : nil;
		if ([containers isKindOfClass:[NSArray class]] && [containers containsObject:container]) return controller;

		if (controller.viewIfLoaded.window) candidate = controller;
	}
	return candidate;
}

+ (void)setInitialComplicationLayout:(id)layout forEditingSceneViewController:(PREditingSceneViewController *)controller {
	BOOL bottom = [SokoPosterModel complicationLayoutUsesBottomLayout:layout];
	objc_setAssociatedObject(controller, kSokoEditorBottomLayoutKey, @(bottom), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (BOOL)editingSceneViewControllerUsesBottomLayout:(PREditingSceneViewController *)controller {
	return [objc_getAssociatedObject(controller, kSokoEditorBottomLayoutKey) boolValue];
}

+ (void)setUsesBottomLayout:(BOOL)usesBottomLayout forEditingSceneViewController:(PREditingSceneViewController *)controller {
	if (usesBottomLayout == [self editingSceneViewControllerUsesBottomLayout:controller]) return;

	objc_setAssociatedObject(controller, kSokoEditorBottomLayoutKey, @(usesBottomLayout), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	SokoEditorPublishUsesBottomLayout(usesBottomLayout);

	[[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
	[self relayoutAnimated:YES];
}

+ (BOOL)editingSceneViewControllerIsDismissing:(PREditingSceneViewController *)controller {
	return [controller respondsToSelector:@selector(isDismissing)] && controller.isDismissing;
}

+ (NSNumber *)bottomLayoutValueForDismissingEditor {
	for (PREditingSceneViewController *controller in gEditingSceneViewControllers.allObjects) {
		if ([self editingSceneViewControllerIsDismissing:controller]) return @([self editingSceneViewControllerUsesBottomLayout:controller]);
	}
	return nil;
}

+ (BOOL)canSwipeEditingSceneViewController:(PREditingSceneViewController *)controller {
	if (!controller || controller.presentedViewController) return NO;
	if (isnan(SokoDockGeometryBottomInset()) || [self isDodging]) return NO;
	if ([self editingSceneViewControllerIsDismissing:controller]) return NO;

	return SokoIsPortrait(controller.view.bounds);
}

+ (BOOL)usesBottomEditingRow {
	return !isnan(SokoDockGeometryBottomInset()) && SokoEditorUsesBottomLayout() && ![self isDodging];
}

+ (void)setIgnoringGraphicComplications:(BOOL)ignoring {
	gIgnoringGraphicComplications = ignoring;
}

+ (BOOL)isIgnoringGraphicComplications {
	return gIgnoringGraphicComplications;
}

+ (BOOL)isDodging {
	return SokoEditorDodging() || gCoveredByHostModalPresentation;
}

+ (void)setCoveredByHostModalPresentation:(BOOL)covered {
	if (covered == gCoveredByHostModalPresentation) return;

	gCoveredByHostModalPresentation = covered;
	[self relayoutAnimated:YES];
}

+ (BOOL)editingSceneViewControllerIsPresentingSheet:(PREditingSceneViewController *)controller {
	static NSArray<NSString *> *sheetSelectors;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		sheetSelectors = @[
			NSStringFromSelector(@selector(presentedComplicationsGallery)),
			NSStringFromSelector(@selector(presentedInlineComplicationsGallery)),
			NSStringFromSelector(@selector(presentedWidgetConfigurationViewController)),
			NSStringFromSelector(@selector(presentedComplicationWidgetConfigurationViewController)),
			NSStringFromSelector(@selector(presentedControlsGallery)),
			NSStringFromSelector(@selector(presentedControlWidgetConfigurationViewController)),
		];
	});

	for (NSString *selector in sheetSelectors) {
		if ([controller respondsToSelector:NSSelectorFromString(selector)] && [controller valueForKey:selector]) return YES;
	}
	return NO;
}

+ (void)editingSceneViewControllerDidChangePresentation:(PREditingSceneViewController *)controller {
	if ([self editingSceneViewControllerIsPresentingSheet:controller]) {
		gDodgingEditingSceneViewController = controller;
		[self updateDodging];
		return;
	}

	__weak PREditingSceneViewController *weakController = controller;
	dispatch_async(dispatch_get_main_queue(), ^{
		PREditingSceneViewController *strongController = weakController;
		BOOL stillDodging = gDodgingEditingSceneViewController == strongController;
		if (stillDodging && ![self editingSceneViewControllerIsPresentingSheet:strongController]) {
			gDodgingEditingSceneViewController = nil;
		}

		[self updateDodging];
	});
}

+ (void)updateDodging {
	BOOL dodging = gDodgingEditingSceneViewController != nil;
	if (dodging == SokoEditorDodging()) return;

	SokoEditorPublishDodging(dodging);
	[self relayoutAnimated:YES];
}

+ (void)relayoutAnimated:(BOOL)animated {
	void (^layout)(void) = ^{
		for (UIViewController *controller in gComplicationContainerViewControllers.allObjects) {
			UIView *view = controller.viewIfLoaded;
			[view setNeedsLayout];
			[view layoutIfNeeded];
		}

		[SokoEditorChrome update];
	};

	if (!animated) {
		layout();
		return;
	}

	UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction;
	[UIView animateWithDuration:0.45 delay:0.0 usingSpringWithDamping:1.0 initialSpringVelocity:0.0 options:options animations:layout completion:nil];
}

@end
