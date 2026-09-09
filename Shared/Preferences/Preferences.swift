import Foundation

struct Preferences {
	var widgetOffset: Double = -18.0
	var notificationOffset: Double = 60.0
}

public final class TweakPreferences: NSObject {
	private(set) var preferences: Preferences = Preferences()

	static let shared = TweakPreferences()

	private let userDefaultsName: String = "moe.waru.soko.preferences"

	func loadPreferences() {
		let defaults = UserDefaults(suiteName: userDefaultsName)
		var loaded = Preferences()
		if let offset = defaults?.object(forKey: "soko_widgetOffset") as? Double,
			offset.isFinite
		{
			loaded.widgetOffset = offset
		}
		if let offset = defaults?.object(forKey: "soko_notificationOffset") as? Double,
			offset.isFinite
		{
			loaded.notificationOffset = offset
		}
		preferences = loaded
	}
}
