#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <math.h>
#import <notify.h>

FOUNDATION_EXPORT NSString *const SokoDockGeometryDidChangeNotification;
FOUNDATION_EXPORT NSString *const SokoEditorDodgingDidChangeNotification;
FOUNDATION_EXPORT NSString *const SokoActiveBottomLayoutDidChangeNotification;
FOUNDATION_EXPORT NSString *const SokoEditorBottomLayoutDidChangeNotification;

static const CGFloat kSokoDockBottomToButtonCenter = 45.0;

FOUNDATION_EXPORT void SokoDockGeometryReload(void);
FOUNDATION_EXPORT void SokoDockGeometryObserve(void (^handler)(void));

FOUNDATION_EXPORT void SokoDockGeometryPublishBottomInset(CGFloat inset);
FOUNDATION_EXPORT CGFloat SokoDockGeometryBottomInset(void);

FOUNDATION_EXPORT void SokoDockPublishActiveUsesBottomLayout(BOOL usesBottomLayout);
FOUNDATION_EXPORT BOOL SokoDockActiveUsesBottomLayout(void);

FOUNDATION_EXPORT void SokoEditorPublishUsesBottomLayout(BOOL usesBottomLayout);
FOUNDATION_EXPORT BOOL SokoEditorUsesBottomLayout(void);

FOUNDATION_EXPORT void SokoEditorPublishDodging(BOOL dodging);
FOUNDATION_EXPORT BOOL SokoEditorDodging(void);
