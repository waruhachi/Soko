#import "SokoCompatibility.h"

static NSString *const kSokoLiquidAssWidgetsAtTopKey = @"dylv.liquidass.clock.widgetsAtTop";
static NSString *const kSokoLiquidAssStyleKey = @"dylv.liquidass.clock.style";

BOOL SokoLiquidAssClockEnabled(void) {
	static BOOL enabled;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		Dl_info info;
		if (!dladdr((const void *)&SokoLiquidAssClockEnabled, &info) || !info.dli_fname) return;

		NSString *directory = [@(info.dli_fname) stringByDeletingLastPathComponent];
		const char *path = [directory stringByAppendingPathComponent:@"liquidass.dylib"].fileSystemRepresentation;
		void *handle = dlopen(path, RTLD_NOW | RTLD_NOLOAD) ?: dlopen(path, RTLD_NOW);
		if (!handle) return;

		BOOL (*hostEnabled)(NSString *) = (BOOL (*)(NSString *))dlsym(handle, "lgHostEnabled");
		enabled = hostEnabled && hostEnabled(@"Clock");
	});

	return enabled;
}

NSDictionary *SokoLiquidAssUserInfoForConfiguration(id configuration) {
	if (![configuration respondsToSelector:@selector(loadUserInfoWithError:)]) return nil;

	NSDictionary *info = [configuration loadUserInfoWithError:NULL];
	return [info isKindOfClass:[NSDictionary class]] ? info : nil;
}

static BOOL SokoLiquidAssStyleIsClassic(NSDictionary *style) {
	if (![style isKindOfClass:[NSDictionary class]]) return NO;

	NSNumber *modern = style[@"modern"];
	NSNumber *weight = style[@"weight"];
	NSNumber *softness = style[@"softness"] ?: @60;
	if (![modern isKindOfClass:[NSNumber class]] || ![weight isKindOfClass:[NSNumber class]] || ![softness isKindOfClass:[NSNumber class]]) return NO;
	if (!isfinite(weight.doubleValue) || weight.doubleValue < 100.0 || weight.doubleValue > 1000.0) return NO;
	if (!isfinite(softness.doubleValue) || softness.doubleValue < 0.0 || softness.doubleValue > 100.0) return NO;

	return !modern.boolValue;
}

BOOL SokoLiquidAssUserInfoUsesBottomLayout(NSDictionary *userInfo) {
	if (![userInfo isKindOfClass:[NSDictionary class]]) return YES;
	if (SokoLiquidAssStyleIsClassic(userInfo[kSokoLiquidAssStyleKey])) return NO;

	id widgetsAtTop = userInfo[kSokoLiquidAssWidgetsAtTopKey];
	return ![widgetsAtTop isKindOfClass:[NSNumber class]] || ![widgetsAtTop boolValue];
}
