#import "SokoHookSupport.h"

%group SokoPosterModel

%hook PRPosterComplicationLayout

- (void)encodeWithCoder:(NSCoder *)coder {
	%orig;

	[SokoPosterModel encodeComplicationLayout:self withCoder:coder];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = %orig;

	[SokoPosterModel decodeComplicationLayout:self withCoder:coder];
	return self;
}

- (void)encodeWithBSXPCCoder:(id)coder {
	%orig;

	[SokoPosterModel encodeComplicationLayout:self withCoder:coder];
}

- (instancetype)initWithBSXPCCoder:(id)coder {
	self = %orig;

	[SokoPosterModel decodeComplicationLayout:self withCoder:coder];
	return self;
}

- (id)copyWithZone:(NSZone *)zone {
	id copy = %orig;

	[SokoPosterModel copyBottomLayoutFromComplicationLayout:self toComplicationLayout:copy];
	return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
	id copy = %orig;

	[SokoPosterModel copyBottomLayoutFromComplicationLayout:self toComplicationLayout:copy];
	return copy;
}

- (BOOL)isEqualToComplicationLayout:(id)layout {
	return %orig && [SokoPosterModel complicationLayout:self hasSameBottomLayoutAsComplicationLayout:layout];
}

- (BOOL)isEqual:(id)object {
	return %orig && [SokoPosterModel complicationLayout:self hasSameBottomLayoutAsComplicationLayout:object];
}

%end

%hook PRPosterConfiguredProperties

- (void)setComplicationLayout:(id)layout {
	if (layout) {
		NSNumber *editorValue = [SokoPosterLayout bottomLayoutValueForDismissingEditor];
		if (editorValue) {
			[SokoPosterModel setBottomLayoutValue:editorValue forComplicationLayout:layout];
		} else if (![SokoPosterModel bottomLayoutValueForComplicationLayout:layout]) {
			[SokoPosterModel copyBottomLayoutFromComplicationLayout:self.complicationLayout toComplicationLayout:layout];
		}
	}

	%orig;
}

%end

%end

void SokoPosterModelInstallHooks(void) {
	%init(SokoPosterModel);
}
