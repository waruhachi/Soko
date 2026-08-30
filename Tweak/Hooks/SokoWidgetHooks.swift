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
			PosterBoardDebugLog.emit(
				"ios16-prominent-display-class-missing",
				every: 1,
				"CSProminentDisplayView is not loaded in iOS 16 SpringBoard"
			)
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
		PosterBoardDebugLog.emit(
			"prominent-display-layout-hook-installed",
			"installed CSProminentDisplayView.layoutSubviews"
		)
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
			if SokoLayout.isPosterBoardProcess {
				PosterBoardDebugLog.emit(
					"prominent-window-hook-fired",
					every: 1,
					"CSProminentEmptyElementView.didMoveToWindow fired "
						+ PosterBoardDebugLog.describe(target)
				)
			}
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
			if SokoLayout.isPosterBoardProcess {
				PosterBoardDebugLog.emit(
					"prominent-superview-hook-fired",
					every: 1,
					"CSProminentEmptyElementView.didMoveToSuperview fired "
						+ PosterBoardDebugLog.describe(target)
				)
			}
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
			if SokoLayout.isPosterBoardProcess {
				PosterBoardDebugLog.emit(
					"prominent-constraints-hook-fired",
					every: 1,
					"CSProminentEmptyElementView.updateConstraints fired "
						+ PosterBoardDebugLog.describe(target)
				)
			}
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
				PosterBoardDebugLog.emit(
					"prominent-layout-hook-fired-\(ObjectIdentifier(target))",
					every: 0.25,
					"CSProminentEmptyElementView.layoutSubviews fired "
						+ PosterBoardDebugLog.describe(target)
				)
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
		PosterBoardDebugLog.emit(
			"prominent-layout-hook-installed",
			"installed CSProminentEmptyElementView.layoutSubviews"
		)
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

enum PRGraphicComplicationContainerViewControllerDidLayoutHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard
			let targetClass = objc_getClass("PRGraphicComplicationContainerViewController")
				as? AnyClass
		else {
			PosterBoardDebugLog.emit(
				"controller-hook-class-missing",
				every: 1,
				"PRGraphicComplicationContainerViewController is not loaded"
			)
			return
		}

		typealias HookType = @convention(c) (UIViewController, Selector) -> Void
		let hook: HookType = { target, selector in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector)
			PosterBoardDebugLog.emit(
				"controller-hook-fired",
				every: 1,
				"controller viewDidLayoutSubviews fired "
					+ PosterBoardDebugLog.describe(target.view)
			)
			SokoLayout.relayoutPosterBoardComplicationViews(in: target)
		}

		MSHookMessageEx(
			targetClass,
			#selector(UIViewController.viewDidLayoutSubviews),
			unsafeBitCast(hook, to: IMP.self),
			&origIMP
		)
		isHooked = true
		PosterBoardDebugLog.emit(
			"controller-hook-installed",
			"installed PRGraphicComplicationContainerViewController.viewDidLayoutSubviews"
		)
	}
}

enum PRWidgetGridViewControllerDidLayoutHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard let targetClass = objc_getClass("PRWidgetGridViewController") as? AnyClass else {
			PosterBoardDebugLog.emit(
				"widget-grid-controller-hook-class-missing",
				every: 1,
				"PRWidgetGridViewController is not loaded"
			)
			return
		}

		typealias HookType = @convention(c) (UIViewController, Selector) -> Void
		let hook: HookType = { target, selector in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector)
			PosterBoardDebugLog.emit(
				"widget-grid-controller-hook-fired",
				every: 1,
				"PRWidgetGridViewController viewDidLayoutSubviews fired "
					+ PosterBoardDebugLog.describe(target.view)
			)
			SokoLayout.relayoutPosterBoardComplicationViews(in: target)
		}

		MSHookMessageEx(
			targetClass,
			#selector(UIViewController.viewDidLayoutSubviews),
			unsafeBitCast(hook, to: IMP.self),
			&origIMP
		)
		isHooked = true
		PosterBoardDebugLog.emit(
			"widget-grid-controller-hook-installed",
			"installed PRWidgetGridViewController.viewDidLayoutSubviews"
		)
	}
}

enum PRSubviewHitTestingViewDidMoveToWindowHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard let targetClass = objc_getClass("PRSubviewHitTestingView") as? AnyClass else {
			PosterBoardDebugLog.emit(
				"hit-testing-window-hook-class-missing",
				every: 1,
				"PRSubviewHitTestingView is not loaded for didMoveToWindow"
			)
			return
		}

		typealias HookType = @convention(c) (UIView, Selector) -> Void
		let hook: HookType = { target, selector in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector)
			PosterBoardDebugLog.emit(
				"hit-testing-window-hook-fired",
				every: 1,
				"PRSubviewHitTestingView.didMoveToWindow fired "
					+ PosterBoardDebugLog.describe(target)
			)
			SokoLayout.schedulePosterBoardComplicationRelayout(target)
		}

		MSHookMessageEx(
			targetClass,
			#selector(UIView.didMoveToWindow),
			unsafeBitCast(hook, to: IMP.self),
			&origIMP
		)
		isHooked = true
		PosterBoardDebugLog.emit(
			"hit-testing-window-hook-installed",
			"installed PRSubviewHitTestingView.didMoveToWindow"
		)
	}
}

enum PRSubviewHitTestingViewLayoutSubviewsHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard let targetClass = objc_getClass("PRSubviewHitTestingView") as? AnyClass else {
			PosterBoardDebugLog.emit(
				"hit-testing-layout-hook-class-missing",
				every: 1,
				"PRSubviewHitTestingView is not loaded for layoutSubviews"
			)
			return
		}

		typealias HookType = @convention(c) (UIView, Selector) -> Void
		let hook: HookType = { target, selector in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector)
			PosterBoardDebugLog.emit(
				"hit-testing-layout-hook-fired",
				every: 1,
				"PRSubviewHitTestingView.layoutSubviews fired "
					+ PosterBoardDebugLog.describe(target)
			)
			SokoLayout.relayoutPosterBoardComplicationViewSynchronously(target)
			SokoLayout.schedulePosterBoardComplicationRelayout(target)
		}

		MSHookMessageEx(
			targetClass,
			#selector(UIView.layoutSubviews),
			unsafeBitCast(hook, to: IMP.self),
			&origIMP
		)
		isHooked = true
		PosterBoardDebugLog.emit(
			"hit-testing-layout-hook-installed",
			"installed PRSubviewHitTestingView.layoutSubviews"
		)
	}
}

enum PRSubviewHitTestingViewSetTransformHook {
	private static var origIMP: IMP?
	private static var isHooked = false

	static func hook() {
		guard !isHooked else { return }
		guard let targetClass = objc_getClass("PRSubviewHitTestingView") as? AnyClass else {
			PosterBoardDebugLog.emit(
				"hit-testing-transform-hook-class-missing",
				every: 1,
				"PRSubviewHitTestingView is not loaded for setTransform:"
			)
			return
		}

		typealias HookType =
			@convention(c) (
				UIView,
				Selector,
				CGAffineTransform
			) -> Void
		let hook: HookType = { target, selector, transform in
			let orig = unsafeBitCast(Self.origIMP, to: HookType.self)
			orig(target, selector, transform)
			SokoLayout.reapplyPosterBoardComplicationTransformOffset(
				to: target,
				systemTransform: transform
			)
		}

		MSHookMessageEx(
			targetClass,
			#selector(setter: UIView.transform),
			unsafeBitCast(hook, to: IMP.self),
			&origIMP
		)
		isHooked = true
		PosterBoardDebugLog.emit(
			"hit-testing-transform-hook-installed",
			"installed PRSubviewHitTestingView.setTransform:"
		)
	}
}
