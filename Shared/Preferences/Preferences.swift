import Foundation
import libroot

struct Preferences: Codable {
	var widgetOffset: Double = -18.0
	var notificationOffset: Double = 60.0

}

public final class TweakPreferences: NSObject {
	private(set) var preferences: Preferences = Preferences()

	static let shared = TweakPreferences()

	private let userDefaultsName: String = "moe.waru.soko.preferences"

	func loadPreferences() throws {
		guard let preferences: UserDefaults = UserDefaults(suiteName: userDefaultsName) else {
			self.preferences = Preferences()
			return
		}

		let dictionary = preferences.dictionaryRepresentation()
		let codableDictionary = NSMutableDictionary()

		for (key, value) in dictionary {
			if key.hasPrefix("soko_") {
				codableDictionary.setValue(value, forKey: key.components(separatedBy: "soko_")[1])
			}
		}

		let json = try JSONSerialization.data(
			withJSONObject: codableDictionary, options: [.fragmentsAllowed, .prettyPrinted])

		if let loadPreferences = try? JSONDecoder().decode(Preferences.self, from: json) {
			self.preferences = loadPreferences
		} else {
			self.preferences = Preferences()
		}
	}
}
