#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "SokoPrivate.h"

static const unsigned long long kSokoComplicationRowElement = 0x8;
static const unsigned long long kSokoEditingVariant = 2;
static const unsigned long long kSokoReticleVariant = 3;

FOUNDATION_EXPORT id SokoIvarObject(id object, const char *name);
FOUNDATION_EXPORT double SokoIvarDouble(id object, const char *name);
FOUNDATION_EXPORT BOOL SokoIsPortrait(CGRect bounds);
