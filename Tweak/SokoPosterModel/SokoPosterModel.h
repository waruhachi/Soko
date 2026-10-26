#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <roothide.h>

#import "../SokoRuntime/SokoPrivate.h"

@interface SokoPosterModel : NSObject
+ (BOOL)isSupported;

+ (NSNumber *)bottomLayoutValueForComplicationLayout:(id)layout;
+ (void)setBottomLayoutValue:(NSNumber *)value forComplicationLayout:(id)layout;
+ (BOOL)complicationLayoutUsesBottomLayout:(id)layout;
+ (BOOL)applyPendingDefaultLayoutToConfiguration:(PRSPosterConfiguration *)configuration;

+ (void)encodeComplicationLayout:(id)layout withCoder:(id)coder;
+ (void)decodeComplicationLayout:(id)layout withCoder:(id)coder;
+ (void)copyBottomLayoutFromComplicationLayout:(id)source toComplicationLayout:(id)copy;
+ (BOOL)complicationLayout:(id)layout hasSameBottomLayoutAsComplicationLayout:(id)other;
@end
