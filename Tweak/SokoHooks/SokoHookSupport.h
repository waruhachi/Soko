#import "../Soko.h"

FOUNDATION_EXPORT BOOL gActivePosterUsesBottomLayout;
FOUNDATION_EXPORT __thread const void *gWallpaperDepthQuerySettings;
FOUNDATION_EXPORT __thread const void *gEditorDepthQueryController;
FOUNDATION_EXPORT __weak CSCoverSheetViewController *gCoverSheetViewController;

FOUNDATION_EXPORT SokoDockCoordinator *SokoCoordinator(void);
FOUNDATION_EXPORT void SokoSetActivePosterUsesBottomLayout(BOOL usesBottomLayout);
FOUNDATION_EXPORT void SokoRefreshDockSoon(void);
FOUNDATION_EXPORT void SokoPost(NSString *name, id object);
FOUNDATION_EXPORT BOOL SokoMoveFooter(UIView *footer, UIView *listView, CGFloat *movedCenterY);
FOUNDATION_EXPORT UIEdgeInsets SokoAdjustedFooterInsets(UIEdgeInsets insets, CSCombinedListViewController *controller);
FOUNDATION_EXPORT BOOL SokoAllowsAddGestureOverRow(BOOL (^orig)(void));

FOUNDATION_EXPORT void SokoDockInstallHooks(void);
FOUNDATION_EXPORT void SokoAstronomyInstallHooks(void);
FOUNDATION_EXPORT void SokoDockListFooterInstallHooks(void);
FOUNDATION_EXPORT void SokoDockContainerFooterInstallHooks(void);
FOUNDATION_EXPORT void SokoDockWidgetDescriptorsInstallHooks(void);
FOUNDATION_EXPORT void SokoDockWidgetGridInstallHooks(void);
FOUNDATION_EXPORT void SokoDockFooterInsetsInstallHooks(void);
FOUNDATION_EXPORT void SokoDockFooterInsetsForOrientationInstallHooks(void);
FOUNDATION_EXPORT void SokoPosterInstallHooks(void);
FOUNDATION_EXPORT void SokoEditorGraphicComplicationsInstallHooks(void);
FOUNDATION_EXPORT void SokoEditorDepthEffectInstallHooks(void);
FOUNDATION_EXPORT void SokoInstallPosterPreviewHooks(Class posterCellClass);
FOUNDATION_EXPORT void SokoSavedDepthEffectInstallHooks(void);
FOUNDATION_EXPORT void SokoSavedDepthSettingsInstallHooks(void);
FOUNDATION_EXPORT void SokoPosterWidgetConfigurationInstallHooks(void);
FOUNDATION_EXPORT void SokoPosterComplicationWidgetConfigurationInstallHooks(void);
FOUNDATION_EXPORT void SokoPosterAddGestureInstallHooks(void);
FOUNDATION_EXPORT void SokoPosterAddGestureForLocationInstallHooks(void);
FOUNDATION_EXPORT void SokoPosterModelInstallHooks(void);
FOUNDATION_EXPORT void SokoLiquidAssEditorDefaultsInstallHooks(void);
FOUNDATION_EXPORT void SokoLiquidAssPosterInstallHooks(void);
FOUNDATION_EXPORT void SokoPhotosEditorInstallHooks(void);
