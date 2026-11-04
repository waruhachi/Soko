#import "SokoHookSupport.h"

%group SokoDockFooterInsetsForOrientation

%hook CSCombinedListViewController

- (UIEdgeInsets)notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:(id)structuredListViewController forOrientation:(long long)orientation {
	UIEdgeInsets insets = %orig;

	return SokoAdjustedFooterInsets(insets, self);
}

%end

%end

void SokoDockFooterInsetsForOrientationInstallHooks(void) {
	%init(SokoDockFooterInsetsForOrientation);
}
