#import "../SokoRuntime/SokoPrivate.h"

@interface FBSSceneSettings (SokoAstronomy)
@property (nonatomic, readonly) CGRect frame;
- (BOOL)pr_usesEditingLayout;
@end

@interface PRPosterEnvironmentImpl : NSObject
- (CGRect)contentCutoutBounds;
- (CGRect)floatingObscurableBounds;
@end

@protocol SokoAstronomyEnvironmentSource <NSObject>
@property (nonatomic, readonly) id environment;
@end

@interface SokoAegirRenderingController : NSObject
- (void)renderer:(id)renderer didInitializeWithEnvironment:(id)environment;
- (void)renderer:(id)renderer didUpdateEnvironment:(id)environment withTransition:(id)transition;
- (void)rendererDidInvalidate:(id)renderer;
@end

@interface SokoAegirEditingController : NSObject
- (void)editor:(id)editor didInitializeWithEnvironment:(id)environment;
- (void)editor:(id)editor didUpdateEnvironment:(id)environment withTransition:(id)transition;
- (void)editorDidInvalidate:(id)editor;
@end
