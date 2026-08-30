import UIKit

enum SokoHooks {
	private static var posterBoardRefreshTimer: Timer?

	static func install() {
		CSProminentDisplayViewLayoutSubviewsHook.hook()
		CSProminentEmptyElementViewDidMoveToWindowHook.hook()
		CSProminentEmptyElementViewDidMoveToSuperviewHook.hook()
		CSProminentEmptyElementViewUpdateConstraintsHook.hook()
		CSProminentEmptyElementViewLayoutSubviewsHook.hook()
		CSProminentEmptyElementViewSetCenterHook.hook()
		NCNotificationListViewDidMoveToWindowHook.hook()
		installNotificationCountIndicatorHooks()
		NCNotificationStructuredListViewControllerWillLayoutHook.hook()
		NCNotificationStructuredListViewControllerDidLayoutHook.hook()
		MRUserSettingsExpandedLockScreenPlatterHook.hook()
	}

	static func installNotificationCountIndicatorHooks() {
		NCNotificationListCountIndicatorViewDidMoveToWindowHook.hook()
		NCNotificationListCountIndicatorViewLayoutSubviewsHook.hook()
		NCNotificationListCountIndicatorViewSetFrameHook.hook()
		NCNotificationListCountIndicatorViewSetCenterHook.hook()
	}

	static func scheduleHookRetries() {
		for delay in [0.5, 1.5, 3.0, 6.0] {
			DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
				PosterBoardDebugLog.emit(
					"hook-retry-\(Bundle.main.bundleIdentifier ?? "nil")-\(delay)",
					"running delayed hook install at +\(delay)s "
						+ "bundle=\(Bundle.main.bundleIdentifier ?? "nil") "
						+ "prominentClass="
						+ "\(objc_getClass("CSProminentEmptyElementView") != nil) "
						+ "prominentDisplayClass="
						+ "\(objc_getClass("CSProminentDisplayView") != nil)"
				)
				install()
				SokoLayout.refreshVisibleViews()
			}
		}
	}

	static func startPosterBoardRefreshMonitor() {
		guard SokoLayout.isPosterBoardProcess, posterBoardRefreshTimer == nil else { return }

		let timer = Timer(timeInterval: 0.5, repeats: true) { _ in
			guard UIApplication.shared.applicationState != .background else { return }
			SokoLayout.refreshVisibleViews()
		}
		posterBoardRefreshTimer = timer
		RunLoop.main.add(timer, forMode: .common)
		PosterBoardDebugLog.emit(
			"refresh-monitor-started",
			"started active PosterBoard refresh monitor interval=0.5s"
		)
	}
}
