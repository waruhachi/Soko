#import "SokoHookSupport.h"

static const uint32_t kSokoBranchLinkMask = 0xFC000000;
static const uint32_t kSokoBranchLinkOpcode = 0x94000000;
static const uint32_t kSokoReturnInstruction = 0xD65F03C0;
static const uint32_t kSokoReturnAAInstruction = 0xD65F0BFF;
static const uint32_t kSokoReturnABInstruction = 0xD65F0FFF;
static const NSUInteger kSokoMaximumScannedInstructions = 64;

static uintptr_t gRendererDepthPredicateStart;
static uintptr_t gRendererDepthPredicateEnd;

static BOOL SokoIsReturnInstruction(uint32_t instruction) {
	return instruction == kSokoReturnInstruction || instruction == kSokoReturnAAInstruction || instruction == kSokoReturnABInstruction;
}

static BOOL SokoLocateRendererDepthPredicate(void) {
	IMP floatingView = class_getMethodImplementation(objc_getClass("PRRenderer"), @selector(floatingView));
	if (!floatingView) return NO;

	const uint32_t *code = ptrauth_strip((const uint32_t *)floatingView, ptrauth_key_function_pointer);
	const uint32_t *predicate = NULL;
	for (NSUInteger i = 0; i < kSokoMaximumScannedInstructions && !predicate; i++) {
		if (SokoIsReturnInstruction(code[i])) return NO;
		if ((code[i] & kSokoBranchLinkMask) != kSokoBranchLinkOpcode) continue;
		int32_t offset = (int32_t)(code[i] << 6) >> 6;
		predicate = code + i + offset;
	}
	if (!predicate) return NO;

	for (NSUInteger i = 0; i < kSokoMaximumScannedInstructions; i++) {
		if (!SokoIsReturnInstruction(predicate[i])) continue;
		gRendererDepthPredicateStart = (uintptr_t)predicate;
		gRendererDepthPredicateEnd = (uintptr_t)(predicate + i);
		return YES;
	}
	return NO;
}

%group SokoRendererDepthEffect

%hook FBSSceneSettings

- (BOOL)pui_isComplicationRowConfigured {
	uintptr_t caller = (uintptr_t)ptrauth_strip(__builtin_return_address(0), ptrauth_key_return_address);
	if (caller > gRendererDepthPredicateStart && caller < gRendererDepthPredicateEnd) return NO;
	return %orig;
}

%end

%end

void SokoRendererDepthEffectInstallHooks(void) {
	if (!SokoLocateRendererDepthPredicate()) return;
	%init(SokoRendererDepthEffect);
}
