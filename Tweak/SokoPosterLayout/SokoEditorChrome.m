#import "SokoEditorChrome.h"

static const CGFloat kSokoLookNameToPageControlSpacing = 10.0;

static const void *kSokoReticleBaseMinYKey = &kSokoReticleBaseMinYKey;
static const void *kSokoStockPageControlConstraintKey = &kSokoStockPageControlConstraintKey;
static const void *kSokoDockPageControlConstraintKey = &kSokoDockPageControlConstraintKey;

static NSHashTable<PREditorRootViewController *> *gEditorRootViewControllers;

@implementation SokoEditorChrome

+ (void)registerEditorRootViewController:(PREditorRootViewController *)controller {
	if (!gEditorRootViewControllers) gEditorRootViewControllers = [NSHashTable weakObjectsHashTable];
	[gEditorRootViewControllers addObject:controller];

	CGRect frame = [NSClassFromString(@"CSProminentLayoutController") frameForElements:kSokoComplicationRowElement variant:kSokoReticleVariant];
	if (!CGRectIsNull(frame)) {
		objc_setAssociatedObject(controller, kSokoReticleBaseMinYKey, @(CGRectGetMinY(frame)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	[self updateLookControlsForEditorRootViewController:controller];
}

+ (void)update {
	for (PREditorRootViewController *controller in gEditorRootViewControllers.allObjects) {
		[self updateReticleForEditorRootViewController:controller];
		[self updateLookControlsForEditorRootViewController:controller];
	}

	for (PREditingSceneViewController *controller in [SokoPosterLayout editingSceneViewControllers]) {
		[self updateAddGestureForEditingSceneViewController:controller];
	}
}

+ (void)updateAddGestureForEditingSceneViewController:(PREditingSceneViewController *)controller {
	UIView *gestureView = [controller respondsToSelector:@selector(complicationsAddGestureView)] ? controller.complicationsAddGestureView : nil;
	CGRect frame = [SokoPosterLayout editingRowFrame];
	if (gestureView && !CGRectIsNull(frame)) gestureView.frame = frame;

	if ([controller respondsToSelector:@selector(_updateAddComplicationsTapGestureAllowed)]) {
		[controller _updateAddComplicationsTapGestureAllowed];
	}
}

+ (void)updateReticleForEditorRootViewController:(PREditorRootViewController *)controller {
	if ([controller respondsToSelector:@selector(updateReticleViewFrames)]) {
		if (controller.isViewLoaded) [controller updateReticleViewFrames];
		return;
	}

	UIView *reticle = [controller respondsToSelector:@selector(graphicComplicationsReticleView)] ? controller.graphicComplicationsReticleView : nil;
	NSNumber *base = objc_getAssociatedObject(controller, kSokoReticleBaseMinYKey);
	if (!reticle || !base) return;

	CGRect target = [NSClassFromString(@"CSProminentLayoutController") frameForElements:kSokoComplicationRowElement variant:kSokoReticleVariant];
	if (CGRectIsNull(target)) return;

	reticle.transform = CGAffineTransformMakeTranslation(0.0, CGRectGetMinY(target) - base.doubleValue);
}

+ (NSLayoutConstraint *)stockPageControlConstraintForEditorRootViewController:(PREditorRootViewController *)controller {
	NSLayoutConstraint *stock = objc_getAssociatedObject(controller, kSokoStockPageControlConstraintKey);
	if (stock) return stock;

	UIView *pageControl = controller.pageControl;
	UIView *divider = controller.controlsDividerVibrancyView;
	UIView *root = controller.viewIfLoaded;

	for (UIView *view = pageControl.superview; view && !stock; view = view.superview) {
		for (NSLayoutConstraint *constraint in view.constraints) {
			BOOL pageControlBottom = constraint.firstItem == pageControl && constraint.firstAttribute == NSLayoutAttributeBottom;
			BOOL dividerTop = constraint.secondItem == divider && constraint.secondAttribute == NSLayoutAttributeTop;
			if (pageControlBottom && dividerTop) {
				stock = constraint;
				break;
			}
		}

		if (view == root) break;
	}

	if (stock) objc_setAssociatedObject(controller, kSokoStockPageControlConstraintKey, stock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	return stock;
}

+ (NSLayoutConstraint *)dockPageControlConstraintForEditorRootViewController:(PREditorRootViewController *)controller {
	NSLayoutConstraint *dock = objc_getAssociatedObject(controller, kSokoDockPageControlConstraintKey);
	if (dock) return dock;

	dock = [controller.pageControl.bottomAnchor constraintEqualToAnchor:controller.view.bottomAnchor];
	objc_setAssociatedObject(controller, kSokoDockPageControlConstraintKey, dock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	return dock;
}

+ (CGFloat)lookControlsHeightForEditorRootViewController:(PREditorRootViewController *)controller {
	UIView *lookName = controller.lookNameLabel;
	CGFloat lookNameHeight = lookName ? [lookName systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height : 0.0;

	return lookNameHeight + kSokoLookNameToPageControlSpacing + controller.pageControl.intrinsicContentSize.height;
}

+ (void)updateLookControlsForEditorRootViewController:(PREditorRootViewController *)controller {
	BOOL hasControls = [controller respondsToSelector:@selector(controlsDividerVibrancyView)] &&
		[controller respondsToSelector:@selector(pageControl)] &&
		[controller respondsToSelector:@selector(lookNameLabel)];
	UIView *root = controller.viewIfLoaded;
	if (!hasControls || !root || !controller.pageControl || !controller.controlsDividerVibrancyView) return;

	NSLayoutConstraint *stock = [self stockPageControlConstraintForEditorRootViewController:controller];
	if (!stock) return;

	NSLayoutConstraint *dock = [self dockPageControlConstraintForEditorRootViewController:controller];
	CGRect bounds = CGRectIsEmpty(root.bounds) ? UIScreen.mainScreen.bounds : root.bounds;
	CGFloat inset = SokoDockGeometryBottomInset();
	BOOL docked = [SokoPosterLayout usesBottomEditingRow] && !isnan(inset) && SokoIsPortrait(bounds);

	if (docked) {
		CGFloat height = [self lookControlsHeightForEditorRootViewController:controller];
		dock.constant = round(kSokoDockBottomToButtonCenter - inset + height / 2.0);
	}

	if (stock.active == !docked && dock.active == docked) return;

	if (docked) {
		stock.active = NO;
		dock.active = YES;
	} else {
		dock.active = NO;
		stock.active = YES;
	}

	[root layoutIfNeeded];
}

@end
