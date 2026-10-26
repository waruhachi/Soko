#import "SokoQuickActions.h"

static BOOL SokoButtonCenterYInQuickActionsView(CSQuickActionsView *quickActions, CGFloat *centerY) {
	UIView *button = nil;
	if ([quickActions respondsToSelector:@selector(flashlightButton)]) button = quickActions.flashlightButton;
	if (!button && [quickActions respondsToSelector:@selector(cameraButton)]) button = quickActions.cameraButton;

	if (button.superview && CGRectGetHeight(button.bounds) > 0.0) {
		*centerY = [quickActions convertPoint:button.center fromView:button.superview].y;
		return YES;
	}

	if ([quickActions respondsToSelector:@selector(_leadingFrameWithOutsets:)]) {
		CGRect frame = [quickActions _leadingFrameWithOutsets:NO];
		if (CGRectIsNull(frame) || CGRectGetHeight(frame) <= 0.0) return NO;

		*centerY = CGRectGetMidY(frame);
		return YES;
	}

	return NO;
}

BOOL SokoQuickActionButtonCenterY(CSCoverSheetView *coverSheetView, CGFloat *centerY) {
	Class quickActionsClass = NSClassFromString(@"CSQuickActionsViewController");
	if (![quickActionsClass respondsToSelector:@selector(deviceSupportsButtons)] || ![quickActionsClass deviceSupportsButtons]) return NO;

	CSQuickActionsView *quickActions = [coverSheetView respondsToSelector:@selector(quickActionsView)] ? coverSheetView.quickActionsView : nil;
	CGFloat buttonCenterY;
	if (!quickActions || !SokoButtonCenterYInQuickActionsView(quickActions, &buttonCenterY)) return NO;

	CGFloat originY = quickActions.center.y - CGRectGetHeight(quickActions.bounds) * 0.5 - quickActions.bounds.origin.y;
	CGFloat y = originY + buttonCenterY;

	UIView *container = quickActions.superview;
	if (container && container != coverSheetView && container != coverSheetView.slideableContentView) {
		y = [container convertPoint:CGPointMake(0.0, y) toView:coverSheetView].y;
	}

	if (centerY) *centerY = y;
	return YES;
}
