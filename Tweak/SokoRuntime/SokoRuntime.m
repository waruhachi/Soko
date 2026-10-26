#import "SokoRuntime.h"

id SokoIvarObject(id object, const char *name) {
	if (!object) return nil;

	Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
	const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
	if (!type || type[0] != '@') return nil;

	return object_getIvar(object, ivar);
}

double SokoIvarDouble(id object, const char *name) {
	if (!object) return 0.0;

	Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
	const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
	if (!type || strcmp(type, @encode(double)) != 0) return 0.0;

	return *(double *)((uint8_t *)(__bridge void *)object + ivar_getOffset(ivar));
}

BOOL SokoIsPortrait(CGRect bounds) {
	return CGRectGetHeight(bounds) >= CGRectGetWidth(bounds);
}
