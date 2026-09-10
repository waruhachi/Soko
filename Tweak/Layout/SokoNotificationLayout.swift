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

	static func expandedLockScreenPlatterPreferenceDidChange() {
		DispatchQueue.main.async {
			for window in posterBoardWindows() {
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
		guard let quickActions = quickActionsView(for: indicator),
			let buttonClass = quickActionsButtonClass,
			let button = bottomVisibleDescendant(of: buttonClass, under: quickActions)
		else {
			restoreNotificationCountIndicatorCenter(indicator)
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
		expanded: Bool
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

		DispatchQueue.main.async {
			guard list.window != nil else { return }
			synchronizeMediaControlsGeometry(
				combinedListController: combinedListController,
				expanded: expanded
			)
		}
	}

	static func synchronizeMediaControlsGeometry(
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

		invokeVoidMethod(
			"_updateListViewContentInset",
			on: combinedListController
		)
		invokeVoidMethod(
			"_updateNotificationListOffsetForExternalUpdate",
			on: combinedListController
		)
		invokeVoidMethod(
			"_updatePresentation",
			on: combinedListController
		)
		combinedListController.viewIfLoaded?.setNeedsLayout()
	}

	static func invokeVoidMethod(
		_ selectorName: String,
		on controller: UIViewController
	) {
		let selector = NSSelectorFromString(selectorName)
		guard controller.responds(to: selector) else { return }

		typealias Method = @convention(c) (UIViewController, Selector) -> Void
		let method = unsafeBitCast(controller.method(for: selector), to: Method.self)
		method(controller, selector)
	}

	static func relayoutNotificationList(_ list: UIView) {
		SokoHooks.installNotificationCountIndicatorHooks()
		MRUserSettingsExpandedLockScreenPlatterHook.hook()

		guard let window = list.window, let listSuperview = list.superview else { return }
		if let listClass = notificationListClass,
			ancestor(of: listSuperview, matching: listClass) != nil
		{
			restoreNotificationListSystemGeometry(list)
			return
		}
		if isExpandedAlbumArtworkActive(for: list) {
			restoreNotificationListSystemGeometry(list)
			scheduleMediaControlsGeometrySynchronization(
				near: list,
				expanded: true
			)
			return
		}
		let notificationOffset = CGFloat(TweakPreferences.shared.preferences.notificationOffset)
		let widgetTop = notificationWidgetTop(near: list, in: listSuperview)
		let targetBottom: CGFloat
		if let quickActions = quickActionsView(for: list),
			let buttonClass = quickActionsButtonClass,
			let button = bottomVisibleDescendant(of: buttonClass, under: quickActions)
		{
			let buttonFrame = listSuperview.convert(button.bounds, from: button)
			targetBottom = min(buttonFrame.minY, widgetTop ?? buttonFrame.minY) + notificationOffset
		} else {
			guard window.safeAreaInsets.bottom <= 0.5 else {
				restoreNotificationListSystemGeometry(list)
				return
			}
			let container = lockScreenContainer(for: list) ?? window
			let bottomInset = max(widgetBottomEdgePadding, container.safeAreaInsets.bottom)
			let bottom = CGPoint(x: container.bounds.midX, y: container.bounds.maxY - bottomInset)
			let defaultOffset = CGFloat(Preferences().notificationOffset)
			let containerBottom = listSuperview.convert(bottom, from: container).y
			targetBottom =
				min(containerBottom, widgetTop ?? containerBottom)
				+ notificationOffset - defaultOffset
		}
		guard targetBottom.isFinite else { return }
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
		let height = max(notificationMinHeight, targetBottom - listFrame.minY)
		listFrame.origin.y = targetBottom - height
		listFrame.size.height = height
		setAssociatedRect(
			listFrame,
			for: list,
			key: &notificationAppliedFrameKey
		)

		if !rectsAreApproximatelyEqual(currentFrame, listFrame) {
			list.frame = listFrame
		}

		alignNotificationCountIndicators(in: list)
		scheduleMediaControlsGeometrySynchronization(
			near: list,
			expanded: false
		)
	}

	static func notificationWidgetTop(near list: UIView, in referenceView: UIView) -> CGFloat? {
		guard usesIOS16ProminentDisplayCompatibility,
			let displayClass = prominentDisplayViewClass,
			let window = list.window
		else { return nil }

		return descendants(of: displayClass, under: window).compactMap { display -> CGFloat? in
			guard !prominentDisplayUsesEditingLayout(display),
				let widget = prominentDisplayComplicationRow(in: display),
				widget.window === list.window,
				isVisibleInHierarchy(widget),
				let constraints = objc_getAssociatedObject(widget, &widgetConstraintsKey)
					as? [NSLayoutConstraint],
				!constraints.isEmpty, constraints.allSatisfy(\.isActive)
			else { return nil }
			let frame = referenceView.convert(widget.bounds, from: widget)
			guard !frame.isEmpty, frame.minY.isFinite else { return nil }
			return frame.minY
		}.min()
	}

	static func restoreNotificationListSystemGeometry(_ list: UIView) {
		let currentFrame = list.frame
		if let appliedFrame = associatedRect(
			for: list,
			key: &notificationAppliedFrameKey
		), rectsAreApproximatelyEqual(currentFrame, appliedFrame),
			let systemFrame = associatedRect(for: list, key: &notificationSystemFrameKey),
			!rectsAreApproximatelyEqual(currentFrame, systemFrame)
		{
			list.frame = systemFrame
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
			return
		}
		for indicator in descendants(of: indicatorClass, under: list) {
			restoreNotificationCountIndicatorCenter(indicator)
		}
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
