import ObjectiveC.runtime
import UIKit

extension SokoLayout {
	static func relayoutPosterBoardProminentWidget(_ widget: UIView) {
		guard isVisibleInHierarchy(widget) else {
			return
		}

		if let hitTestingClass = posterBoardHitTestingViewClass,
			ancestor(of: widget, matching: hitTestingClass) != nil
		{
			restorePosterBoardPosition(widget)
			return
		}

		guard let container = posterBoardPreviewContainer(for: widget) else {
			return
		}

		guard let prominentViewClass else {
			return
		}

		let candidates = descendants(of: prominentViewClass, under: container)
		let target = candidates.last {
			isVisibleInHierarchy($0)
		}
		guard target === widget else {
			return
		}

		applyPosterBoardProminentPosition(to: widget, in: container)
	}

	static func reapplyPosterBoardProminentPositionOffset(
		to view: UIView,
		systemCenter: CGPoint
	) {
		guard isPosterBoardProcess else { return }

		if let hitTestingClass = posterBoardHitTestingViewClass,
			ancestor(of: view, matching: hitTestingClass) != nil
		{
			restorePosterBoardPosition(view)
			CATransaction.begin()
			CATransaction.setDisableActions(true)
			view.layer.position = systemCenter
			CATransaction.commit()
			return
		}

		guard
			let offset =
				(objc_getAssociatedObject(
					view,
					&posterBoardProminentPositionOffsetKey
				) as? NSNumber)?.doubleValue
		else { return }

		CATransaction.begin()
		CATransaction.setDisableActions(true)
		let appliedPosition = CGPoint(
			x: systemCenter.x,
			y: systemCenter.y + CGFloat(offset)
		)
		view.layer.position = appliedPosition
		CATransaction.commit()
		objc_setAssociatedObject(
			view,
			&posterBoardProminentAppliedPositionKey,
			NSValue(cgPoint: appliedPosition),
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
	}

	static func relayoutPosterBoardProminentWidgetSynchronously(_ widget: UIView) {
		guard isPosterBoardProcess,
			!associatedBool(for: widget, key: &posterBoardProminentRelayoutInProgressKey)
		else { return }

		setAssociatedBool(
			true,
			for: widget,
			key: &posterBoardProminentRelayoutInProgressKey
		)
		defer {
			setAssociatedBool(
				false,
				for: widget,
				key: &posterBoardProminentRelayoutInProgressKey
			)
		}
		relayoutPosterBoardProminentWidget(widget)
	}

	static func applyPosterBoardProminentPosition(
		to view: UIView,
		in container: UIView
	) {
		guard view !== container,
			view.window != nil,
			view.window === container.window,
			let superview = view.superview,
			container.bounds.height > 0
		else { return }

		container.layoutIfNeeded()
		view.layoutIfNeeded()

		let previousOffset = CGFloat(
			(objc_getAssociatedObject(view, &posterBoardProminentPositionOffsetKey)
				as? NSNumber)?.doubleValue ?? 0
		)
		let previousAppliedPosition =
			(objc_getAssociatedObject(view, &posterBoardProminentAppliedPositionKey)
			as? NSValue)?.cgPointValue
		let previousOffsetIsApplied =
			previousAppliedPosition.map {
				pointsAreApproximatelyEqual(view.layer.position, $0)
			} ?? false

		guard let frame = logicalFrameIgnoringTransforms(of: view, in: container),
			!frame.isEmpty,
			!frame.isNull
		else { return }

		let widgetOffset = CGFloat(TweakPreferences.shared.preferences.widgetOffset)
		let anchor = posterBoardWidgetAnchor(for: view)
		let targetReferenceY =
			container.bounds.maxY - anchor.inset + widgetOffset
		let currentReferenceY: CGFloat
		if anchor.mode == "screen-bottom" {
			currentReferenceY = frame.maxY
		} else {
			currentReferenceY = frame.midY
		}
		let deltaY = targetReferenceY - currentReferenceY
		guard deltaY.isFinite, abs(deltaY) <= max(container.bounds.height * 1.5, 240)
		else { return }

		let localOrigin = superview.convert(CGPoint.zero, from: container)
		let localOffsetPoint = superview.convert(CGPoint(x: 0, y: deltaY), from: container)
		let localDeltaY = localOffsetPoint.y - localOrigin.y
		let totalOffset =
			previousOffsetIsApplied
			? previousOffset + localDeltaY
			: localDeltaY

		objc_setAssociatedObject(
			view,
			&posterBoardProminentPositionOffsetKey,
			NSNumber(value: Double(totalOffset)),
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)

		CATransaction.begin()
		CATransaction.setDisableActions(true)
		view.layer.position.y += localDeltaY
		CATransaction.commit()
		objc_setAssociatedObject(
			view,
			&posterBoardProminentAppliedPositionKey,
			NSValue(cgPoint: view.layer.position),
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
	}

	static func restorePosterBoardPosition(_ view: UIView) {
		let positionOffset = CGFloat(
			(objc_getAssociatedObject(view, &posterBoardProminentPositionOffsetKey)
				as? NSNumber)?.doubleValue ?? 0
		)
		let appliedPosition =
			(objc_getAssociatedObject(view, &posterBoardProminentAppliedPositionKey)
			as? NSValue)?.cgPointValue
		if positionOffset != 0,
			let appliedPosition,
			pointsAreApproximatelyEqual(view.layer.position, appliedPosition)
		{
			CATransaction.begin()
			CATransaction.setDisableActions(true)
			view.layer.position.y -= positionOffset
			CATransaction.commit()
		}

		objc_setAssociatedObject(
			view,
			&posterBoardProminentPositionOffsetKey,
			nil,
			.OBJC_ASSOCIATION_ASSIGN
		)

		objc_setAssociatedObject(
			view,
			&posterBoardProminentAppliedPositionKey,
			nil,
			.OBJC_ASSOCIATION_ASSIGN
		)
	}
}
