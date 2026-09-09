import ObjectiveC.runtime
import UIKit

extension SokoLayout {
	static func observeComplicationPreferences() {
		guard usesIOS16ProminentDisplayCompatibility else { return }
		let callback: CFNotificationCallback = { _, _, _, _, _ in
			DispatchQueue.main.async {
				SokoLayout.refreshVisibleViews()
			}
		}
		CFNotificationCenterAddObserver(
			CFNotificationCenterGetDarwinNotifyCenter(),
			nil,
			callback,
			"xyz.skitty.morecomplications.prefschanged" as CFString,
			nil,
			.deliverImmediately
		)
	}

	static func complicationContainerHeight() -> CGFloat? {
		guard let provider = objc_getClass("CSGraphicComplicationLayoutProvider") as? AnyClass
		else { return nil }
		let selector = NSSelectorFromString("complicationContainerHeight")
		guard let method = class_getClassMethod(provider, selector) else { return nil }

		typealias Getter = @convention(c) (AnyClass, Selector) -> Double
		let getter = unsafeBitCast(method_getImplementation(method), to: Getter.self)
		let height = getter(provider, selector)
		guard height.isFinite, height > 0 else { return nil }
		return CGFloat(height)
	}
}
