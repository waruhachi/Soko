#import "../SokoRuntime/SokoRuntime.h"
#import "SokoCompatibility.h"

@protocol SokoLiquidAssEditorEnvironment <NSObject>
@property (nonatomic, readonly) id sourceContents;
@end

@protocol SokoLiquidAssEditor <NSObject>
@property (nonatomic, readonly) id<SokoLiquidAssEditorEnvironment> environment;
@end

static NSString *const kSokoLiquidAssWidgetsAtTopKey = @"dylv.liquidass.clock.widgetsAtTop";
static NSString *const kSokoLiquidAssStyleKey = @"dylv.liquidass.clock.style";
static NSString *const kSokoLiquidAssResizeProgressKey = @"dylv.liquidass.clock.resizeProgress";

static const void *kSokoLiquidAssEditorSourceKey = &kSokoLiquidAssEditorSourceKey;

void SokoLiquidAssPrepareEditorDefaults(UIViewController *controller) {
	id<SokoLiquidAssEditor> editor = SokoIvarObject(controller, "_editor");
	id<SokoLiquidAssEditorEnvironment> environment = [editor respondsToSelector:@selector(environment)] ? editor.environment : nil;
	id source = [environment respondsToSelector:@selector(sourceContents)] ? environment.sourceContents : nil;
	if ([source respondsToSelector:@selector(loadUserInfoWithError:)]) {
		objc_setAssociatedObject(source, kSokoLiquidAssEditorSourceKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
}

NSDictionary *SokoLiquidAssEditorUserInfo(id configuration, NSDictionary *info, NSError *error) {
	if (![objc_getAssociatedObject(configuration, kSokoLiquidAssEditorSourceKey) boolValue]) return info;
	if (error && !([error.domain isEqualToString:NSCocoaErrorDomain] && (error.code == NSFileReadNoSuchFileError || error.code == NSFileNoSuchFileError))) return info;
	if (info && ![info isKindOfClass:[NSDictionary class]]) return info;
	if (info[kSokoLiquidAssResizeProgressKey]) return info;

	// Match the preview's full-height default. LiquidAss still gives staged target
	// values precedence over this source fallback, including an explicit zero.
	NSMutableDictionary *defaults = info ? [info mutableCopy] : [NSMutableDictionary dictionary];
	defaults[kSokoLiquidAssResizeProgressKey] = @1.0;
	return defaults;
}

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
