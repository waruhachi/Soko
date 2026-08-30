import ObjectiveC.runtime
import UIKit

extension SokoLayout {
	static func relayoutPosterBoardProminentWidget(_ widget: UIView) {
		PosterBoardDebugLog.emit(
			"prominent-relayout-entered",
			every: 1,
			"prominent relayout entered " + PosterBoardDebugLog.describe(widget)
		)

		guard widget.window != nil,
			!widget.bounds.isEmpty,
			!widget.isHidden,
			widget.alpha > 0.01
		else {
			PosterBoardDebugLog.emit(
				"prominent-visibility-gate",
				every: 1,
				"prominent rejected window=\(widget.window != nil) "
					+ "boundsEmpty=\(widget.bounds.isEmpty) hidden=\(widget.isHidden) "
					+ "alpha=\(widget.alpha)"
			)
			return
		}
		PosterBoardDebugLog.emit(
			"prominent-local-geometry-ready",
			every: 1,
			"prominent local geometry is ready ancestry="
				+ viewAncestryDescription(widget)
		)

		if let hitTestingClass = posterBoardHitTestingViewClass,
			ancestor(of: widget, matching: hitTestingClass) != nil
		{
			PosterBoardDebugLog.emit(
				"prominent-editor-skipped",
				every: 1,
				"prominent is inside PRSubviewHitTestingView; leaving editor at system position"
			)
			restorePosterBoardPosition(widget)
			return
		}

		guard let container = posterBoardPreviewContainer(for: widget) else {
			PosterBoardDebugLog.emit(
				"prominent-container-gate",
				every: 1,
				"prominent rejected because no preview container matched"
			)
			return
		}

		guard let prominentViewClass else {
			PosterBoardDebugLog.emit(
				"prominent-class-gate",
				every: 1,
				"CSProminentEmptyElementView runtime class is unavailable"
			)
			return
		}

		let candidates = descendants(of: prominentViewClass, under: container)
		let target = candidates.last {
			$0.window != nil && !$0.bounds.isEmpty && !$0.isHidden && $0.alpha > 0.01
		}
		PosterBoardDebugLog.emit(
			"prominent-target-selection",
			every: 1,
			"selectionRoot=\(PosterBoardDebugLog.describe(container)) "
				+ "candidates=\(candidates.count) isTarget=\(target === widget) "
				+ "target=\(PosterBoardDebugLog.describe(target))"
		)
		guard target === widget else {
			return
		}

		PosterBoardDebugLog.emit(
			"prominent-relayout-accepted",
			every: 1,
			"prominent accepted container=" + PosterBoardDebugLog.describe(container)
		)
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

	static func reapplyPosterBoardComplicationTransformOffset(
		to view: UIView,
		systemTransform: CGAffineTransform
	) {
		guard isPosterBoardProcess,
			let offset =
				(objc_getAssociatedObject(
					view,
					&posterBoardComplicationTransformOffsetKey
				) as? NSNumber)?.doubleValue
		else { return }

		var appliedTransform = systemTransform
		appliedTransform.ty += CGFloat(offset)
		setPosterBoardTransform(appliedTransform, on: view)

		objc_setAssociatedObject(
			view,
			&posterBoardBaseTransformKey,
			NSValue(cgAffineTransform: systemTransform),
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
		objc_setAssociatedObject(
			view,
			&posterBoardAppliedTransformKey,
			NSValue(cgAffineTransform: appliedTransform),
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)

		PosterBoardDebugLog.emit(
			"reapply-hit-testing-transform-\(ObjectIdentifier(view))",
			every: 0.1,
			"reapplied hit-testing transition offset=\(offset) "
				+ "system=\(PosterBoardDebugLog.transform(systemTransform)) "
				+ "applied=\(PosterBoardDebugLog.transform(appliedTransform))"
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
		let baseTransform = posterBoardBaseTransform(for: view)

		CATransaction.begin()
		CATransaction.setDisableActions(true)
		view.transform = baseTransform
		CATransaction.commit()

		guard let frame = logicalFrameIgnoringTransforms(of: view, in: container),
			!frame.isEmpty,
			!frame.isNull
		else { return }

		let widgetOffset = CGFloat(TweakPreferences.shared.preferences.widgetOffset)
		let anchor = posterBoardWidgetAnchor(for: view)
		let targetReferenceY =
			container.bounds.maxY - anchor.inset + widgetOffset
		let currentReferenceY: CGFloat
		let alignment: String
		if anchor.mode == "screen-bottom" {
			currentReferenceY = frame.maxY
			alignment = "bottom"
		} else {
			currentReferenceY = frame.midY
			alignment = "center"
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
			&posterBoardAppliedTransformKey,
			nil,
			.OBJC_ASSOCIATION_ASSIGN
		)
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

		PosterBoardDebugLog.emit(
			"apply-prominent-position",
			every: 1,
			"apply prominent position frame=\(PosterBoardDebugLog.rect(frame)) "
				+ "anchorMode=\(anchor.mode) anchorInset=\(anchor.inset) "
				+ "alignment=\(alignment) targetReferenceY=\(targetReferenceY) "
				+ "deltaY=\(deltaY) localDeltaY=\(localDeltaY) "
				+ "previousOffset=\(previousOffset) offsetWasApplied=\(previousOffsetIsApplied) "
				+ "totalOffset=\(totalOffset) transform="
				+ PosterBoardDebugLog.transform(view.transform) + " "
				+ PosterBoardDebugLog.describe(view)
		)
	}

}
