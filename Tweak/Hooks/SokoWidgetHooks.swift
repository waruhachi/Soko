import CydiaSubstrate
import ObjectiveC.runtime
import UIKit

enum CSProminentDisplayViewLayoutSubviewsHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard Bundle.main.bundleIdentifier == "com.apple.springboard",
			ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 16
		else { return }
		guard let targetClass = objc_getClass("CSProminentDisplayView") as? AnyClass
		else {
			return
		}

		typealias HookType = @convention(c) (UIView, Selector) -> Void
		let hook: HookType = { target, selector in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector)
			SokoLayout.handleProminentDisplayLayout(target)
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

enum CSProminentEmptyElementViewDidMoveToWindowHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard
			let targetClass = objc_getClass("CSProminentEmptyElementView") as? AnyClass
		else { return }

		typealias HookType = @convention(c) (UIView, Selector) -> Void
		let hook: HookType = { target, selector in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector)
			SokoLayout.scheduleWidgetRelayout(target)
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

enum CSProminentEmptyElementViewDidMoveToSuperviewHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard
			let targetClass = objc_getClass("CSProminentEmptyElementView") as? AnyClass
		else { return }

		typealias HookType = @convention(c) (UIView, Selector) -> Void
		let hook: HookType = { target, selector in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector)
			SokoLayout.scheduleWidgetRelayout(target)
		}

		MSHookMessageEx(
			targetClass,
			#selector(UIView.didMoveToSuperview),
			unsafeBitCast(hook, to: IMP.self),
			&origIMP
		)
		isHooked = true
	}
}

enum CSProminentEmptyElementViewUpdateConstraintsHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard
			let targetClass = objc_getClass("CSProminentEmptyElementView") as? AnyClass
		else { return }

		typealias HookType = @convention(c) (UIView, Selector) -> Void
		let hook: HookType = { target, selector in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector)
			SokoLayout.scheduleWidgetRelayout(target)
		}

		MSHookMessageEx(
			targetClass,
			#selector(UIView.updateConstraints),
			unsafeBitCast(hook, to: IMP.self),
			&origIMP
		)
		isHooked = true
	}
}

enum CSProminentEmptyElementViewLayoutSubviewsHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard
			let targetClass = objc_getClass("CSProminentEmptyElementView") as? AnyClass
		else { return }

		typealias HookType = @convention(c) (UIView, Selector) -> Void
		let hook: HookType = { target, selector in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector)
			if SokoLayout.isPosterBoardProcess {
				SokoLayout.relayoutPosterBoardProminentWidgetSynchronously(target)
			}
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

enum CSProminentEmptyElementViewSetCenterHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard let targetClass = objc_getClass("CSProminentEmptyElementView") as? AnyClass
		else { return }

		typealias HookType = @convention(c) (UIView, Selector, CGPoint) -> Void
		let hook: HookType = { target, selector, center in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector, center)
			SokoLayout.reapplyPosterBoardProminentPositionOffset(
				to: target,
				systemCenter: center
			)
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
