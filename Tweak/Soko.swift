import UIKit

@_cdecl("swift_init")
func tweakInit() {
	TweakPreferences.shared.loadPreferences()

	let notificationName = "moe.waru.soko.preferences.reload" as CFString
	let callback: CFNotificationCallback = { _, _, _, _, _ in
		DispatchQueue.main.async {
			TweakPreferences.shared.loadPreferences()
			SokoLayout.refreshVisibleViews()
		}
	}

	CFNotificationCenterAddObserver(
		CFNotificationCenterGetDarwinNotifyCenter(),
		nil,
		callback,
		notificationName,
		nil,
		CFNotificationSuspensionBehavior.deliverImmediately
	)

	SokoLayout.observeComplicationPreferences()
	SokoHooks.install()
	SokoHooks.scheduleHookRetries()
	SokoHooks.startPosterBoardRefreshMonitor()
}
