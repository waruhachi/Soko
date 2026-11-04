#import "SokoHooks/SokoHookSupport.h"

static id gPosterPreviewLaunchObserver;

static void SokoImageAdded(const struct mach_header *header, intptr_t slide) {
	if (!objc_getClass("PUWallpaperPosterEditorController")) return;

	static dispatch_once_t once;
	dispatch_once(&once, ^{
		SokoPhotosEditorInstallHooks();
	});
}

static void SokoInitDock(void) {
	if (![SokoDockCoordinator isSupported]) return;

	SokoDockInstallHooks();
	if ([objc_getClass("FBSSceneSettings") instancesRespondToSelector:@selector(pr_isDepthEffectDisallowed)] &&
		[objc_getClass("PBUIPosterLockViewController") instancesRespondToSelector:@selector(portalSourceForReplicaView:)]) {
		SokoSavedDepthEffectInstallHooks();
		if ([objc_getClass("PBUIPosterViewController") instancesRespondToSelector:@selector(scene:willUpdateSettings:withTransitionContext:)]) {
			SokoSavedDepthSettingsInstallHooks();
		}
	}

	if ([objc_getClass("NCNotificationListView") instancesRespondToSelector:@selector(_layoutOverlayFooterViewIfNecessary)]) {
		SokoDockListFooterInstallHooks();
	} else if ([objc_getClass("NCNotificationStructuredListView") instancesRespondToSelector:@selector(footerView)]) {
		SokoDockContainerFooterInstallHooks();
	}

	if ([objc_getClass("CSComplicationContainerViewController") instancesRespondToSelector:@selector(setWidgetDescriptors:)]) {
		SokoDockWidgetDescriptorsInstallHooks();
	} else if ([objc_getClass("CSWidgetGridViewController") instancesRespondToSelector:@selector(setComplicationDescriptors:iconLayout:)]) {
		SokoDockWidgetGridInstallHooks();
	}

	Class combinedListClass = objc_getClass("CSCombinedListViewController");
	if ([combinedListClass instancesRespondToSelector:@selector(notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:forOrientation:)]) {
		SokoDockFooterInsetsForOrientationInstallHooks();
	} else if ([combinedListClass instancesRespondToSelector:@selector(notificationStructuredListViewControllerRequestsEdgeInsetsForOverlayFooterView:)]) {
		SokoDockFooterInsetsInstallHooks();
	}
}

static void SokoInitLiquidAssPoster(void) {
	SokoLiquidAssPosterInstallHooks();
	if ([objc_getClass("LGClockEditorState") instancesRespondToSelector:@selector(setController:)] &&
		[objc_getClass("PRPosterConfiguration") instancesRespondToSelector:@selector(loadUserInfoWithError:)]) {
		SokoLiquidAssEditorDefaultsInstallHooks();
	}

	SokoDockGeometryObserve(^{
		[SokoPosterLayout relayoutAnimated:YES];
	});
}

static BOOL SokoInitPosterPreview(void) {
	static BOOL initialized;
	if (initialized) return YES;
	Class posterCellClass = NSClassFromString(@"PosterBoard.LockScreenPosterCollectionViewCell") ?: NSClassFromString(@"_TtC11PosterBoard34LockScreenPosterCollectionViewCell");
	if (posterCellClass) {
		SokoInstallPosterPreviewHooks(posterCellClass);
		initialized = YES;
	}
	return initialized;
}

static void SokoInitPoster(void) {
	if (![SokoPosterLayout isSupported]) return;
	Class editorClass = objc_getClass("PREditingSceneViewController");
	if ([editorClass instancesRespondToSelector:@selector(_hasGraphicComplications)]) {
		SokoEditorGraphicComplicationsInstallHooks();
		// iOS 16's editor compositor obscures bottom widgets with depth enabled.
		// Keep that established policy while enabling the iOS 18 editor path.
		if (@available(iOS 18.0, *)) {
			if ([editorClass instancesRespondToSelector:@selector(_shouldDepthEffectBeDisallowed)] &&
				[editorClass instancesRespondToSelector:@selector(_updateSceneSettingsForDepthEffectDisallowed)]) {
				SokoEditorDepthEffectInstallHooks();
			}
		}
	}
	if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.PosterBoard"] && !SokoInitPosterPreview()) {
		gPosterPreviewLaunchObserver = [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *notification) {
			SokoInitPosterPreview();
			[NSNotificationCenter.defaultCenter removeObserver:gPosterPreviewLaunchObserver];
			gPosterPreviewLaunchObserver = nil;
		}];
	}
	if (SokoLiquidAssClockEnabled()) {
		SokoInitLiquidAssPoster();
		return;
	}

	SokoPosterInstallHooks();

	Class editingSceneClass = objc_getClass("PREditingSceneViewController");
	if ([editingSceneClass instancesRespondToSelector:@selector(setPresentedComplicationWidgetConfigurationViewController:)]) {
		SokoPosterComplicationWidgetConfigurationInstallHooks();
	} else if ([editingSceneClass instancesRespondToSelector:@selector(setPresentedWidgetConfigurationViewController:)]) {
		SokoPosterWidgetConfigurationInstallHooks();
	}

	if ([editingSceneClass instancesRespondToSelector:@selector(_shouldAllowAddComplicationsTapGestureForLocation:)]) {
		SokoPosterAddGestureForLocationInstallHooks();
	} else if ([editingSceneClass instancesRespondToSelector:@selector(_shouldAllowAddComplicationsTapGesture)]) {
		SokoPosterAddGestureInstallHooks();
	}

	SokoDockGeometryObserve(^{
		[SokoPosterLayout relayoutAnimated:YES];
	});

	_dyld_register_func_for_add_image(SokoImageAdded);
}

%ctor {
	if ([SokoPosterModel isSupported]) SokoPosterModelInstallHooks();

	if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
		SokoInitDock();
	} else {
		SokoInitPoster();
	}
}
