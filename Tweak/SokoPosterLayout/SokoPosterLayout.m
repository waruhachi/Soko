#import "SokoPosterLayout.h"
#import <QuartzCore/QuartzCore.h>

@interface SokoPosterDepthMask : NSObject
@property (nonatomic, strong) NSMapTable<UIView *, CAShapeLayer *> *masks;
@end

@implementation SokoPosterDepthMask
@end

static const void *kSokoPosterDepthMaskKey = &kSokoPosterDepthMaskKey;

static CSProminentDisplayView *SokoVisibleProminentDisplay(UIView *view) {
	if (view.hidden) return nil;
	if ([view isKindOfClass:NSClassFromString(@"CSProminentDisplayView")]) return view.alpha > 0.01 ? (CSProminentDisplayView *)view : nil;
	for (UIView *child in view.subviews) {
		CSProminentDisplayView *display = SokoVisibleProminentDisplay(child);
		if (display) return display;
	}
	return nil;
}

static BOOL SokoHasBottomGraphicRow(UIViewController *controller, UIView *editorView, Class graphicClass) {
	UIView *view = controller.viewIfLoaded;
	if (!view || view.hidden || view.alpha <= 0.01 || view.window != editorView.window) return NO;
	if ([controller isKindOfClass:graphicClass]) {
		CGRect row = [view convertRect:view.bounds toView:editorView];
		return !CGRectIsEmpty(row) && CGRectGetMinY(row) >= CGRectGetMidY(editorView.bounds) &&
			CGRectContainsRect(editorView.bounds, row);
	}
	for (UIViewController *child in controller.childViewControllers) {
		if (SokoHasBottomGraphicRow(child, editorView, graphicClass)) return YES;
	}
	return NO;
}

static const CGFloat kSokoBottomRowEditingOffset = 28.0;

static const void *kSokoEditorBottomLayoutKey = &kSokoEditorBottomLayoutKey;
static const void *kSokoLiquidAssConfigurationKey = &kSokoLiquidAssConfigurationKey;
static const void *kSokoLiquidAssUserInfoKey = &kSokoLiquidAssUserInfoKey;

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

+ (void)clearDepthMaskForPosterCell:(UIView *)cell {
	SokoPosterDepthMask *state = objc_getAssociatedObject(cell, kSokoPosterDepthMaskKey);
	for (UIView *foreground in state.masks.keyEnumerator.allObjects) {
		if (foreground.layer.mask == [state.masks objectForKey:foreground]) foreground.layer.mask = nil;
	}
	objc_setAssociatedObject(cell, kSokoPosterDepthMaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)updateDepthMaskForPosterCell:(UIView *)cell {
	id layout = SokoPosterCellComplicationLayout(cell);
	NSArray *widgets = [layout respondsToSelector:@selector(complications)] ? [layout complications] : nil;
	CSProminentDisplayView *display = SokoVisibleProminentDisplay(cell);
	UIView *row = [display respondsToSelector:@selector(complicationRowView)] ? display.complicationRowView : nil;
	NSMutableArray<UIView *> *foregrounds = [NSMutableArray array];
	if ([widgets isKindOfClass:[NSArray class]] && widgets.count && row && !row.hidden &&
		!CGRectIsEmpty(row.bounds) && SokoIsPortrait(display.bounds)) {
		// Both cached snapshots and live portals occupy this foreground interval.
		// Background representations precede the clock and already contain the widgets.
		Class displayClass = NSClassFromString(@"CSProminentDisplayView");
		Class portalClass = NSClassFromString(@"_UIPortalView");
		BOOL afterDisplay = NO;
		for (UIView *sibling in display.superview.subviews) {
			if (sibling == display) { afterDisplay = YES; continue; }
			if (!afterDisplay) continue;
			if ([sibling isKindOfClass:displayClass]) break;
			if (!([sibling isKindOfClass:[UIImageView class]] || (portalClass && [sibling isKindOfClass:portalClass])) ||
				!CGRectEqualToRect(sibling.bounds, display.bounds)) continue;
			CGRect cutout = [row convertRect:row.bounds toView:sibling];
			if (CGRectGetMinY(cutout) >= CGRectGetMidY(sibling.bounds) && CGRectIntersectsRect(cutout, sibling.bounds)) {
				[foregrounds addObject:sibling];
			}
		}
	}
	if (!foregrounds.count) { [self clearDepthMaskForPosterCell:cell]; return; }
	SokoPosterDepthMask *state = objc_getAssociatedObject(cell, kSokoPosterDepthMaskKey);
	if (!state) {
		state = [SokoPosterDepthMask new];
		state.masks = [NSMapTable weakToStrongObjectsMapTable];
		objc_setAssociatedObject(cell, kSokoPosterDepthMaskKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	for (UIView *old in state.masks.keyEnumerator.allObjects) {
		if ([foregrounds containsObject:old]) continue;
		if (old.layer.mask == [state.masks objectForKey:old]) old.layer.mask = nil;
		[state.masks removeObjectForKey:old];
	}
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	for (UIView *foreground in foregrounds) {
		CAShapeLayer *mask = [state.masks objectForKey:foreground];
		if (foreground.layer.mask && foreground.layer.mask != mask) continue;
		if (!mask) {
			mask = [CAShapeLayer layer];mask.fillRule = kCAFillRuleEvenOdd;
			[state.masks setObject:mask forKey:foreground];
		}
		CGRect cutout = [row convertRect:row.bounds toView:foreground];
		UIBezierPath *path = [UIBezierPath bezierPathWithRect:foreground.bounds];
		[path appendPath:[UIBezierPath bezierPathWithRect:cutout]];
		if (!CGRectEqualToRect(mask.frame, foreground.bounds)) mask.frame = foreground.bounds;
		if (!mask.path || !CGPathEqualToPath(mask.path, path.CGPath)) mask.path = path.CGPath;
		if (foreground.layer.mask != mask) foreground.layer.mask = mask;
	}
	[CATransaction commit];
}

+ (BOOL)isSupported {
	Class containerClass = NSClassFromString(@"PRComplicationContainerViewController");
	if ([containerClass instancesRespondToSelector:NSSelectorFromString(@"setWidgetsUseBottomLayout:")]) return NO;

	Class layoutClass = NSClassFromString(@"CSProminentLayoutController");
	return [layoutClass instancesRespondToSelector:@selector(_frameForElement:withBoundingRect:variant:)] &&
		[layoutClass instancesRespondToSelector:@selector(complicationRowElementEditingReticleFrameWithBoundingRect:)] &&
		[layoutClass instancesRespondToSelector:@selector(frameForElements:variant:withBoundingRect:)] &&
		[layoutClass respondsToSelector:@selector(frameForElements:variant:)];
}

+ (BOOL)liquidAssPosterCellUsesBottomLayout:(UIView *)cell {
	id pair = SokoIvarObject(cell, "posterPair");
	id configuration = SokoIvarObject(pair, "configuration");
	if (!configuration) return SokoDockActiveUsesBottomLayout();

	if (objc_getAssociatedObject(cell, kSokoLiquidAssConfigurationKey) != configuration) {
		objc_setAssociatedObject(cell, kSokoLiquidAssConfigurationKey, configuration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		objc_setAssociatedObject(cell, kSokoLiquidAssUserInfoKey, SokoLiquidAssUserInfoForConfiguration(configuration) ?: @{}, OBJC_ASSOCIATION_COPY_NONATOMIC);
	}

	return SokoLiquidAssUserInfoUsesBottomLayout(objc_getAssociatedObject(cell, kSokoLiquidAssUserInfoKey));
}

+ (BOOL)layoutControllerUsesBottomLayout:(CSProminentLayoutController *)layoutController {
	static Class cellClass;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cellClass = NSClassFromString(@"_TtC11PosterBoard34LockScreenPosterCollectionViewCell");
	});

	id environment = [layoutController respondsToSelector:@selector(traitEnvironment)] ? layoutController.traitEnvironment : nil;
	UIView *view = [environment isKindOfClass:[UIViewController class]] ? ((UIViewController *)environment).viewIfLoaded : environment;
	if (![view isKindOfClass:[UIView class]]) view = nil;

	for (; cellClass && view; view = view.superview) {
		if (![view isKindOfClass:cellClass]) continue;
		if (SokoLiquidAssClockEnabled()) return [self liquidAssPosterCellUsesBottomLayout:view];

		return [SokoPosterModel complicationLayoutUsesBottomLayout:SokoPosterCellComplicationLayout(view)];
	}

	return SokoDockActiveUsesBottomLayout();
}

+ (CGRect)frameByAdjustingFrame:(CGRect)frame forElement:(unsigned long long)element boundingRect:(CGRect)boundingRect variant:(unsigned long long)variant layoutController:(CSProminentLayoutController *)layoutController {
	if (element != kSokoComplicationRowElement || variant == kSokoReticleVariant || gComputingStockLayout) return frame;

	BOOL editing = variant == kSokoEditingVariant;
	if (editing && SokoLiquidAssClockEnabled()) return frame;

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

+ (BOOL)editingSceneViewControllerHasBottomWidgetRow:(PREditingSceneViewController *)controller {
	if (![self editingSceneViewControllerEditsLockScreen:controller]) return NO;
	if (!SokoLiquidAssClockEnabled() && ![self editingSceneViewControllerUsesBottomLayout:controller]) return NO;
	UIView *editorView = controller.viewIfLoaded;
	if (!editorView.window || !SokoIsPortrait(editorView.bounds)) return NO;
	Class graphicClass = NSClassFromString(@"PRGraphicComplicationContainerViewController");
	if (!graphicClass) return NO;
	// The native collection is an NSHashTable on iOS 18. Both it and older
	// array-backed implementations support fast enumeration.
	for (UIViewController *container in controller.complicationContainerViewControllers) {
		if (SokoHasBottomGraphicRow(container, editorView, graphicClass)) return YES;
	}
	return NO;
}

+ (void)setUsesBottomLayout:(BOOL)usesBottomLayout forEditingSceneViewController:(PREditingSceneViewController *)controller {
	if (usesBottomLayout == [self editingSceneViewControllerUsesBottomLayout:controller]) return;

	objc_setAssociatedObject(controller, kSokoEditorBottomLayoutKey, @(usesBottomLayout), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	SokoEditorPublishUsesBottomLayout(usesBottomLayout);

	[[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
	[self relayoutAnimated:YES];
	if (@available(iOS 18.0, *)) {
		if ([controller respondsToSelector:@selector(_updateSceneSettingsForDepthEffectDisallowed)]) {
			[controller _updateSceneSettingsForDepthEffectDisallowed];
		}
	}
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
