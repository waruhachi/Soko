import CydiaSubstrate
import ObjectiveC.runtime
import UIKit

enum NCNotificationListViewDidMoveToWindowHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard let targetClass = objc_getClass("NCNotificationListView") as? AnyClass else {
			return
		}

		typealias HookType = @convention(c) (UIView, Selector) -> Void
		let hook: HookType = { target, selector in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector)
			SokoLayout.scheduleNotificationRelayout(target)
		}

		MSHookMessageEx(
			targetClass,
			#selector(UIView.didMoveToWindow),
			unsafeBitCast(hook, to: IMP.self),
			&origIMP
		)
		isHooked = true
	}
}

enum NCNotificationListCountIndicatorViewDidMoveToWindowHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard
			let targetClass = objc_getClass("NCNotificationListCountIndicatorView") as? AnyClass
		else { return }

		typealias HookType = @convention(c) (UIView, Selector) -> Void
		let hook: HookType = { target, selector in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector)
			SokoLayout.alignNotificationCountIndicator(target)
		}

		MSHookMessageEx(
			targetClass,
			#selector(UIView.didMoveToWindow),
			unsafeBitCast(hook, to: IMP.self),
			&origIMP
		)
		isHooked = true
	}
}

enum NCNotificationListCountIndicatorViewLayoutSubviewsHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard
			let targetClass = objc_getClass("NCNotificationListCountIndicatorView") as? AnyClass
		else { return }

		typealias HookType = @convention(c) (UIView, Selector) -> Void
		let hook: HookType = { target, selector in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector)
			SokoLayout.alignNotificationCountIndicator(target)
		}

		MSHookMessageEx(
			targetClass,
			#selector(UIView.layoutSubviews),
			unsafeBitCast(hook, to: IMP.self),
			&origIMP
		)
		isHooked = true
	}
}

enum NCNotificationListCountIndicatorViewSetFrameHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard
			let targetClass = objc_getClass("NCNotificationListCountIndicatorView") as? AnyClass
		else { return }

		typealias HookType = @convention(c) (UIView, Selector, CGRect) -> Void
		let hook: HookType = { target, selector, frame in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector, frame)
			SokoLayout.alignNotificationCountIndicator(target)
		}

		MSHookMessageEx(
			targetClass,
			#selector(setter: UIView.frame),
			unsafeBitCast(hook, to: IMP.self),
			&origIMP
		)
		isHooked = true
	}
}

enum NCNotificationListCountIndicatorViewSetCenterHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard
			let targetClass = objc_getClass("NCNotificationListCountIndicatorView") as? AnyClass
		else { return }

		typealias HookType = @convention(c) (UIView, Selector, CGPoint) -> Void
		let hook: HookType = { target, selector, center in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector, center)
			SokoLayout.alignNotificationCountIndicator(target)
		}

		MSHookMessageEx(
			targetClass,
			#selector(setter: UIView.center),
			unsafeBitCast(hook, to: IMP.self),
			&origIMP
		)
		isHooked = true
	}
}

enum NCNotificationStructuredListViewControllerWillLayoutHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard
			let targetClass = objc_getClass("NCNotificationStructuredListViewController")
				as? AnyClass
		else { return }

		typealias HookType = @convention(c) (UIViewController, Selector) -> Void
		let hook: HookType = { target, selector in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector)
			SokoLayout.relayoutNotificationList(in: target)
		}

		MSHookMessageEx(
			targetClass,
			#selector(UIViewController.viewWillLayoutSubviews),
			unsafeBitCast(hook, to: IMP.self),
			&origIMP
		)
		isHooked = true
	}
}

enum NCNotificationStructuredListViewControllerDidLayoutHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard
			let targetClass = objc_getClass("NCNotificationStructuredListViewController")
				as? AnyClass
		else { return }

		typealias HookType = @convention(c) (UIViewController, Selector) -> Void
		let hook: HookType = { target, selector in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector)
			SokoLayout.relayoutNotificationList(in: target)
		}

		MSHookMessageEx(
			targetClass,
			#selector(UIViewController.viewDidLayoutSubviews),
			unsafeBitCast(hook, to: IMP.self),
			&origIMP
		)
		isHooked = true
	}
}

enum MRUserSettingsExpandedLockScreenPlatterHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard Bundle.main.bundleIdentifier == "com.apple.springboard",
			ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 16
		else {
			return
		}
		guard let targetClass = objc_getClass("MRUserSettings") as? AnyClass else {
			PosterBoardDebugLog.emit(
				"media-remote-user-settings-class-missing",
				every: 1,
				"MRUserSettings is not loaded yet"
			)
			return
		}

		let selector = NSSelectorFromString("setPrefersExpandedLockScreenPlatter:")
		guard class_getInstanceMethod(targetClass, selector) != nil else {
			PosterBoardDebugLog.emit(
				"media-remote-expanded-platter-selector-missing",
				every: 1,
				"MRUserSettings.setPrefersExpandedLockScreenPlatter: is unavailable"
			)
			return
		}

		typealias HookType = @convention(c) (NSObject, Selector, Bool) -> Void
		let hook: HookType = { target, selector, expanded in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector, expanded)
			SokoLayout.expandedLockScreenPlatterPreferenceDidChange(expanded)
		}

		MSHookMessageEx(
			targetClass,
			selector,
			unsafeBitCast(hook, to: IMP.self),
			&origIMP
		)
		isHooked = true
		PosterBoardDebugLog.emit(
			"media-remote-expanded-platter-hook-installed",
			"installed iOS 16 MRUserSettings expanded lock-screen platter hook"
		)
	}
}
