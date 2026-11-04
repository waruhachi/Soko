#import "SokoRuntime.h"

id SokoIvarObject(id object, const char *name) {
	if (!object) return nil;

	Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
	const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
	if (!type || type[0] != '@') return nil;

	return MSHookIvar<id>(object, name);
}

double SokoIvarDouble(id object, const char *name) {
	if (!object) return 0.0;

	Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
	const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
	if (!type || strcmp(type, @encode(double)) != 0) return 0.0;

	return MSHookIvar<double>(object, name);
}

id SokoPosterCellComplicationLayout(id cell) {
	if (!cell) return nil;

	Ivar ivar = class_getInstanceVariable(object_getClass(cell), "complicationLayout");
	if (!ivar) return nil;
	// This known Swift reference field can have an empty Objective-C type encoding.
	const char *type = ivar_getTypeEncoding(ivar);
	if (type && type[0] && type[0] != '@') return nil;
	return MSHookIvar<id>(cell, "complicationLayout");
}

BOOL SokoIsPortrait(CGRect bounds) {
	return CGRectGetHeight(bounds) >= CGRectGetWidth(bounds);
}
