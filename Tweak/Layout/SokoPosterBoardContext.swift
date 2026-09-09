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
				return match
			}
		}

		if let match = ancestor(of: view, classNameContaining: "LockScreenPosterCollectionViewCell")
		{
			return match
		}

		for className in [
			"_TtC11PosterBoard24PosterRackCollectionView",
			"PosterBoard.PosterRackCollectionView",
		] {
			if let targetClass = objc_getClass(className) as? AnyClass,
				let match = ancestor(of: view, matching: targetClass)
			{
				return match
			}
		}

		if let match = ancestor(of: view, classNameContaining: "PosterRackCollectionView") {
			return match
		}

		return nil
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

		guard mediaControlsAreVisible(near: view) else { return false }
		guard let getter = mediaRemoteExpandedPlatterGetter else {
			return false
		}

		return getter()
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
