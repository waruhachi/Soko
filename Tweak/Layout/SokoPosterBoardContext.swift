import ObjectiveC.runtime
import UIKit

extension SokoLayout {
	static func posterBoardPreviewContainer(for view: UIView) -> UIView? {
		for className in [
			"_TtC11PosterBoard34LockScreenPosterCollectionViewCell",
			"PosterBoard.LockScreenPosterCollectionViewCell",
		] {
			if let targetClass = objc_getClass(className) as? AnyClass,
				let match = ancestor(of: view, matching: targetClass)
			{
				PosterBoardDebugLog.emit(
					"preview-container-cell",
					every: 1,
					"matched preview container class=\(className) "
						+ PosterBoardDebugLog.describe(match)
				)
				return match
			}
		}

		if let match = ancestor(of: view, classNameContaining: "LockScreenPosterCollectionViewCell")
		{
			PosterBoardDebugLog.emit(
				"preview-container-cell-fragment",
				every: 1,
				"matched preview container by cell fragment "
					+ PosterBoardDebugLog.describe(match)
			)
			return match
		}

		for className in [
			"_TtC11PosterBoard24PosterRackCollectionView",
			"PosterBoard.PosterRackCollectionView",
		] {
			if let targetClass = objc_getClass(className) as? AnyClass,
				let match = ancestor(of: view, matching: targetClass)
			{
				PosterBoardDebugLog.emit(
					"preview-container-rack",
					every: 1,
					"matched preview container class=\(className) "
						+ PosterBoardDebugLog.describe(match)
				)
				return match
			}
		}

		if let match = ancestor(of: view, classNameContaining: "PosterRackCollectionView") {
			PosterBoardDebugLog.emit(
				"preview-container-rack-fragment",
				every: 1,
				"matched preview container by rack fragment "
					+ PosterBoardDebugLog.describe(match)
			)
			return match
		}

		PosterBoardDebugLog.emit(
			"preview-container-missing",
			every: 1,
			"no preview container matched ancestry=\(viewAncestryDescription(view))"
		)
		return nil
	}

	static func posterBoardAnchorContainer(
		for view: UIView,
		controller: UIViewController
	) -> UIView? {
		if let previewContainer = posterBoardPreviewContainer(for: view) {
			PosterBoardDebugLog.emit(
				"anchor-container-preview",
				every: 1,
				"using preview anchor " + PosterBoardDebugLog.describe(previewContainer)
			)
			return previewContainer
		}

		if controller.view !== view {
			PosterBoardDebugLog.emit(
				"anchor-container-controller-view",
				every: 1,
				"using controller.view anchor "
					+ PosterBoardDebugLog.describe(controller.view)
			)
			return controller.view
		}

		let fallback = controller.view.superview ?? view.window
		PosterBoardDebugLog.emit(
			"anchor-container-fallback",
			every: 1,
			"using controller root fallback anchor " + PosterBoardDebugLog.describe(fallback)
		)
		return fallback
	}

	static func owningViewController(of view: UIView) -> UIViewController? {
		var responder: UIResponder? = view
		while let next = responder?.next {
			if let controller = next as? UIViewController {
				return controller
			}
			responder = next
		}
		return nil
	}

	static func isExpandedAlbumArtworkActive(for view: UIView) -> Bool {
		guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 16,
			view.window != nil
		else { return false }

		let mediaControlsVisible = mediaControlsAreVisible(near: view)
		PosterBoardDebugLog.emit(
			"media-controls-visibility",
			every: 1,
			"iOS 16 media controls visible=\(mediaControlsVisible)"
		)
		guard mediaControlsVisible else { return false }
		guard let getter = mediaRemoteExpandedPlatterGetter else {
			PosterBoardDebugLog.emit(
				"media-remote-expanded-platter-getter-missing",
				every: 5,
				"MRPrefersExpandedLockScreenPlatter is unavailable"
			)
			return false
		}

		let expanded = getter()
		PosterBoardDebugLog.emit(
			"media-remote-expanded-platter-read",
			every: 1,
			"iOS 16 expanded lock-screen platter read=\(expanded)"
		)
		return expanded
	}

	static func mediaControlsAreVisible(near view: UIView) -> Bool {
		guard let combinedListController = combinedListController(near: view) else {
			return false
		}

		return combinedListControllerIsShowingMediaControls(combinedListController)
	}

	static func combinedListController(near view: UIView) -> UIViewController? {
		guard let combinedListViewControllerClass else { return nil }

		var controller = owningViewController(of: view)
		while let candidate = controller {
			if candidate.isKind(of: combinedListViewControllerClass) {
				return candidate
			}
			controller = candidate.parent
		}

		guard let rootController = view.window?.rootViewController else { return nil }
		return firstViewController(
			of: combinedListViewControllerClass,
			under: rootController
		)
	}

	static func combinedListControllerIsShowingMediaControls(
		_ combinedListController: UIViewController
	) -> Bool {
		let selector = NSSelectorFromString("isShowingMediaControls")
		guard combinedListController.responds(to: selector) else { return false }

		typealias Getter = @convention(c) (UIViewController, Selector) -> Bool
		let getter = unsafeBitCast(
			combinedListController.method(for: selector),
			to: Getter.self
		)
		return getter(combinedListController, selector)
	}

	static func firstViewController(
		of targetClass: AnyClass,
		under controller: UIViewController
	) -> UIViewController? {
		if controller.isKind(of: targetClass) {
			return controller
		}

		if let presented = controller.presentedViewController,
			let match = firstViewController(of: targetClass, under: presented)
		{
			return match
		}

		for child in controller.children {
			if let match = firstViewController(of: targetClass, under: child) {
				return match
			}
		}

		return nil
	}

	static func ancestor(of view: UIView, matching targetClass: AnyClass) -> UIView? {
		var cursor: UIView? = view
		while let candidate = cursor {
			if candidate.isKind(of: targetClass) {
				return candidate
			}
			cursor = candidate.superview
		}
		return nil
	}

	static func ancestor(
		of view: UIView,
		classNameContaining fragment: String
	) -> UIView? {
		var cursor: UIView? = view
		while let candidate = cursor {
			if NSStringFromClass(type(of: candidate)).contains(fragment) {
				return candidate
			}
			cursor = candidate.superview
		}
		return nil
	}

	static func viewAncestryDescription(_ view: UIView) -> String {
		var names: [String] = []
		var cursor: UIView? = view
		while let candidate = cursor, names.count < 16 {
			names.append(NSStringFromClass(type(of: candidate)))
			cursor = candidate.superview
		}
		return names.joined(separator: " <- ")
	}

	static func isVisibleInHierarchy(_ view: UIView) -> Bool {
		guard view.window != nil, !view.bounds.isEmpty else { return false }

		var cursor: UIView? = view
		while let candidate = cursor {
			if candidate.isHidden || candidate.alpha <= 0.01 {
				return false
			}
			cursor = candidate.superview
		}
		return true
	}

	static func isWidgetGridHitTestingView(_ view: UIView) -> Bool {
		guard let window = view.window, !view.bounds.isEmpty else { return false }
		let maximumWidgetGridHeight = min(200, window.bounds.height * 0.4)
		return view.bounds.height <= maximumWidgetGridHeight
	}

	static func pointsAreApproximatelyEqual(
		_ left: CGPoint,
		_ right: CGPoint
	) -> Bool {
		abs(left.x - right.x) <= 0.5 && abs(left.y - right.y) <= 0.5
	}

	static func rectsAreApproximatelyEqual(
		_ left: CGRect,
		_ right: CGRect
	) -> Bool {
		pointsAreApproximatelyEqual(left.origin, right.origin)
			&& abs(left.width - right.width) <= 0.5
			&& abs(left.height - right.height) <= 0.5
	}

}
