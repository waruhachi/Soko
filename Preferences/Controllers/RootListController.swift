import Foundation
import Preferences
import UIKit

class RootListController: PSListController {
	private let suiteName: String! = "moe.waru.soko.preferences"

	override var specifiers: NSMutableArray? {
		get {
			if let specifiers = value(forKey: "_specifiers") as? NSMutableArray {
				return specifiers
			} else {
				let specifiers = loadSpecifiers(fromPlistName: "Root", target: self)
				setValue(specifiers, forKey: "_specifiers")
				return specifiers
			}
		}
		set {
			super.specifiers = newValue
		}
	}

	override func setPreferenceValue(_ value: Any, specifier: PSSpecifier) {
		guard let preferences: UserDefaults = UserDefaults(suiteName: suiteName) else { return }
		preferences.setValue(value, forKey: "soko_\(specifier.properties["key"] as! String)")
		CFNotificationCenterPostNotification(
			CFNotificationCenterGetDarwinNotifyCenter(),
			CFNotificationName("moe.waru.soko.preferences.reload" as CFString),
			nil,
			nil,
			true)

		super.setPreferenceValue(value, specifier: specifier)
	}

	private func specifier(for key: String) -> PSSpecifier? {
		(specifiers as? [PSSpecifier])?.first { $0.properties["key"] as? String == key }
	}

	@objc func resetWidgetOffset() {
		guard let specifier = specifier(for: "widgetOffset") else { return }
		setPreferenceValue(-18.0, specifier: specifier)
		reloadSpecifiers()
	}

	@objc func resetNotificationOffset() {
		guard let specifier = specifier(for: "notificationOffset") else { return }
		setPreferenceValue(60.0, specifier: specifier)
		reloadSpecifiers()
	}
}
