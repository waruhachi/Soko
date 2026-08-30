import ObjectiveC.runtime
import UIKit

extension SokoLayout {
	static func scheduleNotificationRelayout(_ list: UIView) {
		guard list.window != nil else { return }
		guard !associatedBool(for: list, key: &notificationRelayoutPendingKey) else { return }

		setAssociatedBool(true, for: list, key: &notificationRelayoutPendingKey)
		DispatchQueue.main.async {
			setAssociatedBool(false, for: list, key: &notificationRelayoutPendingKey)
			guard list.window != nil else { return }
			relayoutNotificationList(list)
		}
	}

	static func refreshNotificationLists(in window: UIWindow?) {
		guard let window, let notificationListClass else { return }
		for list in descendants(of: notificationListClass, under: window) {
			scheduleNotificationRelayout(list)
		}
	}

	static func expandedLockScreenPlatterPreferenceDidChange(_ expanded: Bool) {
		PosterBoardDebugLog.emit(
			"media-remote-expanded-platter-state",
			"iOS 16 expanded lock-screen platter preference=\(expanded)"
		)

		let windows = posterBoardWindows()
		DispatchQueue.main.async {
			for window in windows {
				refreshNotificationLists(in: window)
			}
		}
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
			for window in posterBoardWindows() {
				refreshNotificationLists(in: window)
			}
		}
	}

	static func relayoutNotificationList(in controller: UIViewController) {
		guard let notificationListClass else { return }
		guard let list = firstDescendant(of: notificationListClass, under: controller.view) else {
			return
		}

		relayoutNotificationList(list)
	}

	static func alignNotificationCountIndicator(_ indicator: UIView) {
		guard !associatedBool(for: indicator, key: &notificationCountIndicatorAligningKey)
		else { return }
		guard indicator.window != nil else { return }
		if isExpandedAlbumArtworkActive(for: indicator) {
			restoreNotificationCountIndicatorCenter(indicator)
			return
		}
		guard let superview = indicator.superview else { return }
		guard let quickActions = quickActionsView(for: indicator) else { return }
		guard let buttonClass = quickActionsButtonClass else { return }
		guard let button = bottomVisibleDescendant(of: buttonClass, under: quickActions) else {
			return
		}

		let currentCenter = indicator.center
		let systemCenter: CGPoint
		if let appliedCenter = associatedPoint(
			for: indicator,
			key: &notificationCountIndicatorAppliedCenterKey
		), pointsAreApproximatelyEqual(currentCenter, appliedCenter),
			let storedSystemCenter = associatedPoint(
				for: indicator,
				key: &notificationCountIndicatorSystemCenterKey
			)
		{
			systemCenter = storedSystemCenter
		} else {
			systemCenter = currentCenter
			setAssociatedPoint(
				systemCenter,
				for: indicator,
				key: &notificationCountIndicatorSystemCenterKey
			)
		}

		let buttonFrame = superview.convert(button.bounds, from: button)
		var targetCenter = systemCenter
		targetCenter.y = buttonFrame.midY
		setAssociatedPoint(
			targetCenter,
			for: indicator,
			key: &notificationCountIndicatorAppliedCenterKey
		)
		guard !pointsAreApproximatelyEqual(currentCenter, targetCenter) else { return }

		setAssociatedBool(true, for: indicator, key: &notificationCountIndicatorAligningKey)
		indicator.center = targetCenter
		setAssociatedBool(false, for: indicator, key: &notificationCountIndicatorAligningKey)
	}

	static func scheduleMediaControlsGeometrySynchronization(
		near list: UIView,
		expanded: Bool,
		geometryChanged: Bool
	) {
		guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 16,
			let combinedListController = combinedListController(near: list),
			combinedListControllerIsShowingMediaControls(combinedListController)
		else { return }
		guard
			!associatedBool(
				for: combinedListController,
				key: &mediaControlsLayoutSynchronizingKey
			)
		else { return }

		let previousState =
			objc_getAssociatedObject(
				combinedListController,
				&mediaControlsExpandedStateKey
			) as? NSNumber
		let stateChanged = previousState?.boolValue != expanded
		objc_setAssociatedObject(
			combinedListController,
			&mediaControlsExpandedStateKey,
			NSNumber(value: expanded),
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)

		guard !expanded else { return }
		guard stateChanged else { return }

		PosterBoardDebugLog.emit(
			"media-controls-layout-scheduled-\(ObjectIdentifier(combinedListController))",
			"iOS 16 media layout synchronization scheduled expanded=\(expanded) "
				+ "stateChanged=\(stateChanged) geometryChanged=\(geometryChanged)"
		)

		DispatchQueue.main.async {
			guard list.window != nil else { return }
			synchronizeMediaControlsGeometry(
				near: list,
				combinedListController: combinedListController,
				expanded: expanded
			)
		}
	}

	static func synchronizeMediaControlsGeometry(
		near list: UIView,
		combinedListController: UIViewController,
		expanded: Bool
	) {
		guard combinedListControllerIsShowingMediaControls(combinedListController)
		else { return }
		if let getter = mediaRemoteExpandedPlatterGetter, getter() != expanded {
			return
		}
		guard
			!associatedBool(
				for: combinedListController,
				key: &mediaControlsLayoutSynchronizingKey
			)
		else { return }

		setAssociatedBool(
			true,
			for: combinedListController,
			key: &mediaControlsLayoutSynchronizingKey
		)
		defer {
			setAssociatedBool(
				false,
				for: combinedListController,
				key: &mediaControlsLayoutSynchronizingKey
			)
		}

		let adjunctBefore = adjunctViewDescription(for: combinedListController)
		let listBefore = PosterBoardDebugLog.describe(list)

		let insetUpdated = invokeVoidMethod(
			"_updateListViewContentInset",
			on: combinedListController
		)
		let offsetUpdated = invokeVoidMethod(
			"_updateNotificationListOffsetForExternalUpdate",
			on: combinedListController
		)
		let presentationUpdated = invokeVoidMethod(
			"_updatePresentation",
			on: combinedListController
		)
		combinedListController.viewIfLoaded?.setNeedsLayout()

		PosterBoardDebugLog.emit(
			"media-controls-layout-pass-\(ObjectIdentifier(combinedListController))",
			"iOS 16 media layout synchronization pass expanded=\(expanded) "
				+ "inset=\(insetUpdated) "
				+ "offset=\(offsetUpdated) presentation=\(presentationUpdated) "
				+ "listBefore={\(listBefore)} listAfter={\(PosterBoardDebugLog.describe(list))} "
				+ "adjunctBefore={\(adjunctBefore)} "
				+ "adjunctAfter={\(adjunctViewDescription(for: combinedListController))}"
		)
	}

	static func invokeVoidMethod(
		_ selectorName: String,
		on controller: UIViewController
	) -> Bool {
		let selector = NSSelectorFromString(selectorName)
		guard controller.responds(to: selector) else { return false }

		typealias Method = @convention(c) (UIViewController, Selector) -> Void
		let method = unsafeBitCast(controller.method(for: selector), to: Method.self)
		method(controller, selector)
		return true
	}

	static func adjunctViewDescription(
		for combinedListController: UIViewController
	) -> String {
		let selector = NSSelectorFromString("adjunctListViewController")
		guard combinedListController.responds(to: selector) else { return "unavailable" }

		typealias Getter = @convention(c) (UIViewController, Selector) -> AnyObject?
		let getter = unsafeBitCast(combinedListController.method(for: selector), to: Getter.self)
		guard let controller = getter(combinedListController, selector) as? UIViewController
		else { return "nil" }
		return PosterBoardDebugLog.describe(controller.viewIfLoaded)
	}

	static func relayoutNotificationList(_ list: UIView) {
		SokoHooks.installNotificationCountIndicatorHooks()
		MRUserSettingsExpandedLockScreenPlatterHook.hook()

		guard list.window != nil else { return }
		if isExpandedAlbumArtworkActive(for: list) {
			let geometryChanged = restoreNotificationListSystemGeometry(list)
			scheduleMediaControlsGeometrySynchronization(
				near: list,
				expanded: true,
				geometryChanged: geometryChanged
			)
			PosterBoardDebugLog.emit(
				"notification-expanded-artwork-\(ObjectIdentifier(list))",
				every: 1,
				"iOS 16 expanded album artwork active; using system notification geometry "
					+ PosterBoardDebugLog.describe(list)
			)
			return
		}
		guard let quickActions = quickActionsView(for: list) else { return }
		guard let buttonClass = quickActionsButtonClass else { return }
		guard let button = bottomVisibleDescendant(of: buttonClass, under: quickActions) else {
			return
		}
		guard let listSuperview = list.superview else { return }

		let buttonFrame = listSuperview.convert(button.bounds, from: button)
		let targetBottom =
			buttonFrame.minY + CGFloat(TweakPreferences.shared.preferences.notificationOffset)
		let currentFrame = list.frame
		let systemFrame: CGRect
		if let appliedFrame = associatedRect(
			for: list,
			key: &notificationAppliedFrameKey
		), rectsAreApproximatelyEqual(currentFrame, appliedFrame),
			let storedSystemFrame = associatedRect(
				for: list,
				key: &notificationSystemFrameKey
			)
		{
			systemFrame = storedSystemFrame
		} else {
			systemFrame = currentFrame
			setAssociatedRect(
				systemFrame,
				for: list,
				key: &notificationSystemFrameKey
			)
		}

		var listFrame = systemFrame
		let height = targetBottom - listFrame.minY
		guard height >= notificationMinHeight else { return }
		listFrame.size.height = height
		setAssociatedRect(
			listFrame,
			for: list,
			key: &notificationAppliedFrameKey
		)

		let geometryChanged = !rectsAreApproximatelyEqual(currentFrame, listFrame)
		if geometryChanged {
			list.frame = listFrame
		}

		alignNotificationCountIndicators(in: list)
		scheduleMediaControlsGeometrySynchronization(
			near: list,
			expanded: false,
			geometryChanged: geometryChanged
		)
	}

	@discardableResult
	static func restoreNotificationListSystemGeometry(_ list: UIView) -> Bool {
		let currentFrame = list.frame
		var geometryChanged = false
		if let appliedFrame = associatedRect(
			for: list,
			key: &notificationAppliedFrameKey
		), rectsAreApproximatelyEqual(currentFrame, appliedFrame),
			let systemFrame = associatedRect(for: list, key: &notificationSystemFrameKey),
			!rectsAreApproximatelyEqual(currentFrame, systemFrame)
		{
			list.frame = systemFrame
			geometryChanged = true
		}

		objc_setAssociatedObject(
			list,
			&notificationSystemFrameKey,
			nil,
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
		objc_setAssociatedObject(
			list,
			&notificationAppliedFrameKey,
			nil,
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)

		guard let indicatorClass = notificationCountIndicatorClass else {
			return geometryChanged
		}
		for indicator in descendants(of: indicatorClass, under: list) {
			restoreNotificationCountIndicatorCenter(indicator)
		}
		return geometryChanged
	}

	static func restoreNotificationCountIndicatorCenter(_ indicator: UIView) {
		guard !associatedBool(for: indicator, key: &notificationCountIndicatorAligningKey)
		else { return }

		let currentCenter = indicator.center
		if let appliedCenter = associatedPoint(
			for: indicator,
			key: &notificationCountIndicatorAppliedCenterKey
		), pointsAreApproximatelyEqual(currentCenter, appliedCenter),
			let systemCenter = associatedPoint(
				for: indicator,
				key: &notificationCountIndicatorSystemCenterKey
			), !pointsAreApproximatelyEqual(currentCenter, systemCenter)
		{
			setAssociatedBool(
				true,
				for: indicator,
				key: &notificationCountIndicatorAligningKey
			)
			indicator.center = systemCenter
			setAssociatedBool(
				false,
				for: indicator,
				key: &notificationCountIndicatorAligningKey
			)
		}

		objc_setAssociatedObject(
			indicator,
			&notificationCountIndicatorSystemCenterKey,
			nil,
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
		objc_setAssociatedObject(
			indicator,
			&notificationCountIndicatorAppliedCenterKey,
			nil,
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
	}

}
