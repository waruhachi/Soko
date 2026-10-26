#import "SokoCompatibility.h"

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
