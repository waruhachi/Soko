#import "SokoHookSupport.h"

%group SokoPosterPreview

%hook SokoLockScreenPosterCollectionViewCell

- (void)layoutSubviews {
	%orig;
	[SokoPosterLayout updateDepthMaskForPosterCell:self];
}

- (void)prepareForReuse {
	%orig;
	[SokoPosterLayout clearDepthMaskForPosterCell:self];
}

%end

%end

void SokoInstallPosterPreviewHooks(Class posterCellClass) {
	%init(SokoPosterPreview, SokoLockScreenPosterCollectionViewCell = posterCellClass);
}
