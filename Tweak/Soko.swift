import UIKit

@_cdecl("swift_init")
func tweakInit() {
	PosterBoardDebugLog.emit(
		"init",
		"loaded process=\(ProcessInfo.processInfo.processName) "
			+ "bundle=\(Bundle.main.bundleIdentifier ?? "nil") "
			+ "executable=\(Bundle.main.executableURL?.lastPathComponent ?? "nil")"
	)
	SokoLog.emit("[Soko] Initializing Tweak")

	do {
		try TweakPreferences.shared.loadPreferences()
	} catch {
		SokoLog.emit("[Soko] Failed to load preferences: \(error)")
	}
	let preferences = TweakPreferences.shared.preferences

	SokoLog.emit("[Soko] Loaded preferences: \(preferences)")

	let notificationName = "moe.waru.soko.preferences.reload" as CFString
	let callback: CFNotificationCallback = { _, _, _, _, _ in
		if (try? TweakPreferences.shared.loadPreferences()) != nil {
			SokoLog.emit(
				"[Soko] Reloaded preferences: \(TweakPreferences.shared.preferences)"
			)
			DispatchQueue.main.async {
				SokoLayout.refreshVisibleViews()
			}
		} else {
			SokoLog.emit("[Soko] Failed to reload prefs")
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

	SokoHooks.install()
	SokoHooks.scheduleHookRetries()
	SokoHooks.startPosterBoardRefreshMonitor()
}
