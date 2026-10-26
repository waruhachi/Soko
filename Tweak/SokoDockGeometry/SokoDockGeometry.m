#import "SokoDockGeometry.h"

NSString *const SokoDockGeometryDidChangeNotification = @"moe.waru.soko.dock.geometry";
NSString *const SokoEditorDodgingDidChangeNotification = @"moe.waru.soko.dock.editor.dodging";
NSString *const SokoActiveBottomLayoutDidChangeNotification = @"moe.waru.soko.dock.active.bottom";
NSString *const SokoEditorBottomLayoutDidChangeNotification = @"moe.waru.soko.dock.editor.bottom";

static const double kSokoInsetScale = 64.0;

static CGFloat gBottomInset = NAN;
static BOOL gActiveBottom;
static BOOL gEditorBottom;
static BOOL gDodging;
static BOOL gLoaded;

static void (^gObserver)(void);

static int SokoToken(NSString *name) {
	static NSMutableDictionary<NSString *, NSNumber *> *tokens;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		tokens = [NSMutableDictionary dictionary];
	});

	@synchronized(tokens) {
		NSNumber *token = tokens[name];
		if (!token) {
			int value = NOTIFY_TOKEN_INVALID;
			if (notify_register_check(name.UTF8String, &value) != NOTIFY_STATUS_OK) return NOTIFY_TOKEN_INVALID;

			token = @(value);
			tokens[name] = token;
		}
		return token.intValue;
	}
}

static uint64_t SokoReadState(NSString *name) {
	int token = SokoToken(name);
	uint64_t state = 0;
	if (token == NOTIFY_TOKEN_INVALID || notify_get_state(token, &state) != NOTIFY_STATUS_OK) return 0;

	return state;
}

static void SokoWriteState(NSString *name, uint64_t state) {
	int token = SokoToken(name);
	if (token == NOTIFY_TOKEN_INVALID || notify_set_state(token, state) != NOTIFY_STATUS_OK) return;

	notify_post(name.UTF8String);
}

static uint64_t SokoEncodeInset(CGFloat inset) {
	if (!isfinite(inset) || inset < 0.0) return 0;

	return (uint64_t)llround(inset * kSokoInsetScale) + 1;
}

static void SokoLoadIfNeeded(void) {
	if (!gLoaded) SokoDockGeometryReload();
}

static void SokoPublishFlag(BOOL *storage, BOOL value, NSString *name) {
	SokoLoadIfNeeded();
	if (*storage == value) return;

	*storage = value;
	SokoWriteState(name, value ? 1 : 0);
}

void SokoDockGeometryReload(void) {
	uint64_t inset = SokoReadState(SokoDockGeometryDidChangeNotification);
	gBottomInset = inset ? (CGFloat)((double)(inset - 1) / kSokoInsetScale) : NAN;

	gActiveBottom = SokoReadState(SokoActiveBottomLayoutDidChangeNotification) != 0;
	gEditorBottom = SokoReadState(SokoEditorBottomLayoutDidChangeNotification) != 0;
	gDodging = SokoReadState(SokoEditorDodgingDidChangeNotification) != 0;
	gLoaded = YES;
}

static void SokoDockGeometryDidChange(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	dispatch_async(dispatch_get_main_queue(), ^{
		SokoDockGeometryReload();
		if (gObserver) gObserver();
	});
}

void SokoDockGeometryObserve(void (^handler)(void)) {
	gObserver = [handler copy];

	NSArray<NSString *> *names = @[
		SokoDockGeometryDidChangeNotification,
		SokoEditorDodgingDidChangeNotification,
		SokoActiveBottomLayoutDidChangeNotification,
		SokoEditorBottomLayoutDidChangeNotification,
	];

	CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
	for (NSString *name in names) {
		CFNotificationCenterAddObserver(darwin, NULL, SokoDockGeometryDidChange, (__bridge CFStringRef)name, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	}
}

void SokoDockGeometryPublishBottomInset(CGFloat inset) {
	SokoLoadIfNeeded();

	uint64_t state = SokoEncodeInset(inset);
	if (state == SokoEncodeInset(gBottomInset)) return;

	gBottomInset = state ? inset : NAN;
	SokoWriteState(SokoDockGeometryDidChangeNotification, state);
}

CGFloat SokoDockGeometryBottomInset(void) {
	SokoLoadIfNeeded();
	return gBottomInset;
}

void SokoDockPublishActiveUsesBottomLayout(BOOL usesBottomLayout) {
	SokoPublishFlag(&gActiveBottom, usesBottomLayout, SokoActiveBottomLayoutDidChangeNotification);
}

BOOL SokoDockActiveUsesBottomLayout(void) {
	SokoLoadIfNeeded();
	return gActiveBottom;
}

void SokoEditorPublishUsesBottomLayout(BOOL usesBottomLayout) {
	SokoPublishFlag(&gEditorBottom, usesBottomLayout, SokoEditorBottomLayoutDidChangeNotification);
}

BOOL SokoEditorUsesBottomLayout(void) {
	SokoLoadIfNeeded();
	return gEditorBottom;
}

void SokoEditorPublishDodging(BOOL dodging) {
	SokoPublishFlag(&gDodging, dodging, SokoEditorDodgingDidChangeNotification);
}

BOOL SokoEditorDodging(void) {
	SokoLoadIfNeeded();
	return gDodging;
}
