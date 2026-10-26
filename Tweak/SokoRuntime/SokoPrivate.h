#import <UIKit/UIKit.h>

@class CSCombinedListViewController;
@class CSMainPageContentViewController;
@class CSProminentDisplayViewController;
@class CSQuickActionsView;
@class NCNotificationStructuredListViewController;
@class PRPosterConfiguredProperties;
@class PRSPosterConfiguration;
@class SBFLockScreenDateViewController;

@interface UIViewController (BaseBoardUI)
- (void)bs_addChildViewController:(UIViewController *)child withSuperview:(UIView *)superview;
- (void)bs_removeChildViewController:(UIViewController *)child;
@end

@interface CSCoverSheetView : UIView
@property (nonatomic, readonly) UIView *slideableContentView;
@property (nonatomic, readonly) CSQuickActionsView *quickActionsView;
@property (nonatomic, readonly) double dateViewScale;
- (void)_layoutDateView;
@end

@interface CSCoverSheetViewController : UIViewController
@property (nonatomic, readonly) UIViewController *complicationContainerViewController;
@property (nonatomic, readonly) SBFLockScreenDateViewController *dateViewController;
@property (nonatomic, readonly) CSMainPageContentViewController *mainPageContentViewController;
- (double)listMinY;
- (void)_updateComplicationsContainerView;
@end

@interface SBFLockScreenDateViewController : UIViewController
@property (nonatomic, strong) UIViewController *complicationContainerViewController;
@end

@interface CSMainPageContentViewController : UIViewController
@property (nonatomic, readonly) CSCombinedListViewController *combinedListViewController;
@end

@interface CSQuickActionsViewController : UIViewController
+ (BOOL)deviceSupportsButtons;
@end

@interface CSQuickActionsView : UIView
@property (nonatomic, readonly) UIView *flashlightButton;
@property (nonatomic, readonly) UIView *cameraButton;
- (CGRect)_leadingFrameWithOutsets:(BOOL)outsets;
@end

@interface CSComplicationContainerViewController : UIViewController
@property (nonatomic, copy) NSArray *widgetDescriptors;
@end

@interface CSWidgetGridViewController : UIViewController
- (void)setComplicationDescriptors:(NSArray *)complicationDescriptors iconLayout:(id)iconLayout;
@end

@interface CSProminentDisplayView : UIView
@property (nonatomic, readonly) UIView *vibrancyEffectView;
@end

@interface CSProminentDisplayViewController : UIViewController
@property (nonatomic, readonly) double complicationRowAlpha;
- (void)_updateViewColors;
- (void)setVibrancyContentType:(long long)contentType;
- (void)interactiveTransition:(id)transition didUpdate:(double)progress;
- (void)setContentAlpha:(double)alpha forElements:(unsigned long long)elements;
@end

@interface CSProminentLayoutController : NSObject
@property (nonatomic, readonly) id traitEnvironment;
+ (CGRect)frameForElements:(unsigned long long)elements variant:(unsigned long long)variant;
- (instancetype)initWithTraitEnvironment:(id<UITraitEnvironment>)traitEnvironment;
- (CGRect)frameForElements:(unsigned long long)elements withBoundingRect:(CGRect)rect;
- (CGRect)frameForElements:(unsigned long long)elements variant:(unsigned long long)variant withBoundingRect:(CGRect)rect;
- (CGRect)_frameForElement:(unsigned long long)element withBoundingRect:(CGRect)rect variant:(unsigned long long)variant;
- (CGRect)complicationRowElementEditingReticleFrameWithBoundingRect:(CGRect)rect;
@end

@interface CSComplicationManager : NSObject
- (void)_updateComplicationsForActivePosterConfiguration;
@end

@interface BSUIVibrancyEffectView : UIView
@property (nonatomic, readonly) UIView *contentView;
@property (nonatomic, strong) id configuration;
@property (nonatomic) unsigned long long contentType;
@end

@interface CSCombinedListViewController : UIViewController
- (void)layoutListView;
- (UIEdgeInsets)notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:(id)structuredListViewController;
- (UIEdgeInsets)notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:(id)structuredListViewController forOrientation:(long long)orientation;
@end

@interface NCNotificationMasterList : NSObject
- (void)updateListViewVisibleRect;
- (void)updateListViewVisibleRectForSize:(CGSize)size;
- (void)_scrollToSystemPreferredPageTypeIfPossible;
- (BOOL)isNotificationHistoryRevealed;
@end

@interface NCNotificationStructuredListViewController : UIViewController
@property (nonatomic, readonly) UIScrollView *masterListView;
@property (nonatomic, readonly) UIScrollView *scrollView;
@property (nonatomic, readonly) NCNotificationMasterList *masterList;
@property (nonatomic, readonly) NCNotificationMasterList *listModel;
- (void)_updateListEdgeInsetsForSize:(CGSize)size;
@end

@interface NCNotificationListView : UIScrollView
@property (nonatomic, strong) UIView *overlayFooterView;
@property (nonatomic) UIEdgeInsets overlayFooterViewEdgeInsets;
@property (nonatomic, readonly) CGRect visibleRect;
- (void)_layoutOverlayFooterViewIfNecessary;
@end

@protocol NCNotificationStructuredListViewDelegate <NSObject>
@optional
- (void)notificationStructuredListView:(UIView *)structuredListView didChangeFooterCenterY:(double)footerCenterY;
@end

@interface NCNotificationStructuredListView : UIView
@property (nonatomic, strong) UIView *footerView;
@property (nonatomic, readonly) UIEdgeInsets footerInsets;
@property (nonatomic, weak) id<NCNotificationStructuredListViewDelegate> delegate;
@end

@interface PRPosterComplicationLayout : NSObject
- (BOOL)isEqualToComplicationLayout:(id)layout;
- (void)encodeWithBSXPCCoder:(id)coder;
- (instancetype)initWithBSXPCCoder:(id)coder;
@end

@interface PRPosterConfiguredProperties : NSObject
@property (nonatomic, copy) id complicationLayout;
@end

@interface PRSPosterConfiguration : NSObject
@property (nonatomic, readonly) id _path;
- (id)pr_loadComplicationLayoutWithError:(NSError **)error;
- (NSDictionary *)loadUserInfoWithError:(NSError **)error;
@end

@interface PRMutablePosterConfiguration : NSObject
- (instancetype)_initWithPath:(id)path;
- (id)loadComplicationLayoutWithError:(NSError **)error;
- (BOOL)storeComplicationLayout:(id)layout error:(NSError **)error;
@end

@interface PRSWallpaperObserverState : NSObject
@property (nonatomic, readonly) PRSPosterConfiguration *activeLock;
@end

@interface PRComplicationContainerViewController : UIViewController
@end

@interface PREditor : NSObject
- (void)setCoveredByHostModalPresentation:(BOOL)covered;
@end

@interface PREditorRootViewController : UIViewController
@property (nonatomic, readonly) UIView *graphicComplicationsReticleView;
@property (nonatomic, readonly) UIView *pageControl;
@property (nonatomic, readonly) UIView *lookNameLabel;
@property (nonatomic, readonly) UIView *controlsDividerVibrancyView;
- (void)updateReticleViewFrames;
@end

@interface PREditingSceneViewController : UIViewController
@property (nonatomic, readonly) NSString *posterRole;
@property (nonatomic, readonly, getter=isDismissing) BOOL dismissing;
@property (nonatomic, readonly) NSArray *complicationContainerViewControllers;
@property (nonatomic, readonly) UIView *complicationsAddGestureView;
@property (nonatomic, strong) UINavigationController *presentedComplicationsGallery;
@property (nonatomic, strong) UINavigationController *presentedInlineComplicationsGallery;
@property (nonatomic, strong) UIViewController *presentedWidgetConfigurationViewController;
@property (nonatomic, strong) UIViewController *presentedComplicationWidgetConfigurationViewController;
@property (nonatomic, strong) UIViewController *presentedControlsGallery;
@property (nonatomic, strong) UIViewController *presentedControlWidgetConfigurationViewController;
- (instancetype)initWithProvider:(id)provider contents:(id)contents configurableOptions:(id)configurableOptions configuredProperties:(PRPosterConfiguredProperties *)configuredProperties additionalInfo:(id)additionalInfo;
- (BOOL)_hasGraphicComplications;
- (BOOL)_shouldAllowAddComplicationsTapGesture;
- (BOOL)_shouldAllowAddComplicationsTapGestureForLocation:(long long)location;
- (void)_updateAddComplicationsTapGestureAllowed;
@end

@interface PUWallpaperPosterEditorController : NSObject
@property (nonatomic, strong) UILabel *hintLabel;
- (BOOL)_createHintLabelIfNeeded;
- (void)_updateHintLabelAnimated:(BOOL)animated;
@end
