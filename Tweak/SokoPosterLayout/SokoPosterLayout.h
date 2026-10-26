#import "../SokoDockGeometry/SokoDockGeometry.h"
#import "../SokoPosterModel/SokoPosterModel.h"
#import "../SokoRuntime/SokoRuntime.h"

@interface SokoPosterLayout : NSObject
+ (BOOL)isSupported;

+ (CGRect)frameByAdjustingFrame:(CGRect)frame forElement:(unsigned long long)element boundingRect:(CGRect)boundingRect variant:(unsigned long long)variant layoutController:(CSProminentLayoutController *)layoutController;
+ (CGRect)reticleFrameByAdjustingFrame:(CGRect)frame layoutController:(CSProminentLayoutController *)layoutController boundingRect:(CGRect)boundingRect;
+ (CGRect)editingRowFrame;

+ (void)registerComplicationContainerViewController:(UIViewController *)controller;
+ (BOOL)registerEditingSceneViewController:(PREditingSceneViewController *)controller;
+ (NSArray<PREditingSceneViewController *> *)editingSceneViewControllers;
+ (PREditingSceneViewController *)editingSceneViewControllerForComplicationContainerViewController:(UIViewController *)container;

+ (void)setInitialComplicationLayout:(id)layout forEditingSceneViewController:(PREditingSceneViewController *)controller;
+ (BOOL)editingSceneViewControllerUsesBottomLayout:(PREditingSceneViewController *)controller;
+ (void)setUsesBottomLayout:(BOOL)usesBottomLayout forEditingSceneViewController:(PREditingSceneViewController *)controller;
+ (NSNumber *)bottomLayoutValueForDismissingEditor;

+ (BOOL)canSwipeEditingSceneViewController:(PREditingSceneViewController *)controller;
+ (BOOL)usesBottomEditingRow;

+ (void)setIgnoringGraphicComplications:(BOOL)ignoring;
+ (BOOL)isIgnoringGraphicComplications;

+ (BOOL)isDodging;
+ (void)setCoveredByHostModalPresentation:(BOOL)covered;
+ (void)editingSceneViewControllerDidChangePresentation:(PREditingSceneViewController *)controller;

+ (void)relayoutAnimated:(BOOL)animated;
@end
