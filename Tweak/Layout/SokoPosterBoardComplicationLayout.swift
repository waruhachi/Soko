import ObjectiveC.runtime
import UIKit

extension SokoLayout {
	static func schedulePosterBoardComplicationRelayout(_ view: UIView) {
		guard isPosterBoardProcess else { return }
		guard view.window != nil else {
			restorePosterBoardPosition(view)
			return
		}
		guard !associatedBool(for: view, key: &posterBoardRelayoutPendingKey) else {
			return
		}

		setAssociatedBool(true, for: view, key: &posterBoardRelayoutPendingKey)
		DispatchQueue.main.async {
			setAssociatedBool(false, for: view, key: &posterBoardRelayoutPendingKey)
			relayoutPosterBoardComplicationView(view)
		}
	}

	static func relayoutPosterBoardComplicationViews(in controller: UIViewController) {
		guard isPosterBoardProcess else { return }
		guard isPosterBoardWidgetGridController(controller),
			let hitTestingClass = posterBoardHitTestingViewClass
		else {
			PosterBoardDebugLog.emit(
				"controller-relayout-class-gate",
				every: 1,
				"controller relayout rejected controller=\(NSStringFromClass(type(of: controller))) "
					+ "controllerClass=\(isPosterBoardWidgetGridController(controller)) "
					+ "hitTestingClass=\(posterBoardHitTestingViewClass != nil)"
			)
			return
		}

		let candidates = descendants(of: hitTestingClass, under: controller.view)
		let target =
			controller.view.isKind(of: hitTestingClass)
				&& isWidgetGridHitTestingView(controller.view)
			? controller.view
			: candidates.last {
				isVisibleInHierarchy($0) && isWidgetGridHitTestingView($0)
			}
		let prominentDescendantCount: Int
		if let target, let prominentViewClass {
			prominentDescendantCount = descendants(of: prominentViewClass, under: target).count
		} else {
			prominentDescendantCount = -1
		}
		for (index, candidate) in candidates.enumerated() {
			let subviewClasses = candidate.subviews
				.map { NSStringFromClass(type(of: $0)) }
				.joined(separator: ",")
			PosterBoardDebugLog.emit(
				"controller-candidate-\(ObjectIdentifier(candidate))",
				every: 1,
				"controller candidate[\(index)] isControllerView=\(candidate === controller.view) "
					+ PosterBoardDebugLog.describe(candidate)
					+ " directSubviews=[\(subviewClasses)] "
					+ "layer=\(NSStringFromClass(type(of: candidate.layer))) "
					+ "sublayers=\(candidate.layer.sublayers?.count ?? 0) "
					+ "hasContents=\(candidate.layer.contents != nil)"
			)
		}
		if let targetSuperview = target?.superview {
			let siblingClasses = targetSuperview.subviews
				.map { NSStringFromClass(type(of: $0)) }
				.joined(separator: ",")
			PosterBoardDebugLog.emit(
				"controller-target-siblings-\(ObjectIdentifier(targetSuperview))",
				every: 1,
				"controller target superview=" + PosterBoardDebugLog.describe(targetSuperview)
					+ " siblings=[\(siblingClasses)]"
			)
		}
		PosterBoardDebugLog.emit(
			"controller-relayout-target",
			every: 1,
			"controller candidates=\(candidates.count) target="
				+ PosterBoardDebugLog.describe(target)
				+ " targetAncestry=\(target.map(viewAncestryDescription) ?? "nil")"
				+ " prominentDescendants=\(prominentDescendantCount)"
		)

		for candidate in candidates {
			if candidate === target {
				relayoutPosterBoardComplicationView(candidate, controller: controller)
			} else {
				restorePosterBoardPosition(candidate)
			}
		}
	}

	static func relayoutPosterBoardComplicationViewSynchronously(_ view: UIView) {
		guard isPosterBoardProcess,
			view.window != nil,
			!associatedBool(
				for: view,
				key: &posterBoardComplicationRelayoutInProgressKey
			)
		else { return }

		setAssociatedBool(
			true,
			for: view,
			key: &posterBoardComplicationRelayoutInProgressKey
		)
		defer {
			setAssociatedBool(
				false,
				for: view,
				key: &posterBoardComplicationRelayoutInProgressKey
			)
		}
		relayoutPosterBoardComplicationView(view)
	}

	static func relayoutPosterBoardComplicationView(
		_ view: UIView,
		controller suppliedController: UIViewController? = nil
	) {
		PosterBoardDebugLog.emit(
			"hit-testing-relayout-entered",
			every: 1,
			"hit-testing relayout entered " + PosterBoardDebugLog.describe(view)
		)
		guard isPosterBoardProcess, view.window != nil else {
			PosterBoardDebugLog.emit(
				"hit-testing-relayout-process-window-gate",
				every: 1,
				"hit-testing rejected isPosterBoard=\(isPosterBoardProcess) window=\(view.window != nil)"
			)
			restorePosterBoardPosition(view)
			return
		}

		let controller = suppliedController ?? owningViewController(of: view)
		guard let controller,
			isPosterBoardWidgetGridController(controller),
			let hitTestingClass = posterBoardHitTestingViewClass
		else {
			PosterBoardDebugLog.emit(
				"hit-testing-relayout-controller-gate",
				every: 1,
				"hit-testing rejected owner=\(controller.map { NSStringFromClass(type(of: $0)) } ?? "nil") "
					+ "controllerClass=\(controller.map(isPosterBoardWidgetGridController) ?? false) "
					+ "hitTestingClass=\(posterBoardHitTestingViewClass != nil)"
			)
			restorePosterBoardPosition(view)
			return
		}

		let candidates = descendants(of: hitTestingClass, under: controller.view)
		let target =
			controller.view.isKind(of: hitTestingClass)
				&& isWidgetGridHitTestingView(controller.view)
			? controller.view
			: candidates.last {
				isVisibleInHierarchy($0) && isWidgetGridHitTestingView($0)
			}
		guard target === view,
			let container = posterBoardAnchorContainer(for: view, controller: controller)
		else {
			PosterBoardDebugLog.emit(
				"hit-testing-relayout-target-gate",
				every: 1,
				"hit-testing target rejected candidates=\(candidates.count) isTarget=\(target === view) "
					+ "target=\(PosterBoardDebugLog.describe(target))"
			)
			restorePosterBoardPosition(view)
			return
		}

		PosterBoardDebugLog.emit(
			"hit-testing-relayout-accepted",
			every: 1,
			"hit-testing accepted container=" + PosterBoardDebugLog.describe(container)
		)
		applyPosterBoardPosition(to: view, in: container)
	}

	static func applyPosterBoardPosition(to view: UIView, in container: UIView) {
		guard view !== container,
			view.window != nil,
			view.window === container.window,
			view.superview != nil,
			container.bounds.height > 0
		else {
			PosterBoardDebugLog.emit(
				"apply-relationship-gate",
				every: 1,
				"apply rejected sameView=\(view === container) viewWindow=\(view.window != nil) "
					+ "sameWindow=\(view.window === container.window) "
					+ "superview=\(view.superview != nil) containerHeight=\(container.bounds.height)"
			)
			return
		}

		container.layoutIfNeeded()
		view.layoutIfNeeded()
		guard let frame = logicalFrameIgnoringTransforms(of: view, in: container),
			!frame.isEmpty,
			!frame.isNull
		else {
			PosterBoardDebugLog.emit(
				"apply-frame-gate",
				every: 1,
				"apply rejected logicalFrame=unavailable"
			)
			return
		}

		let widgetOffset = CGFloat(TweakPreferences.shared.preferences.widgetOffset)
		let anchor = posterBoardWidgetAnchor(for: view)
		let targetBottom =
			container.bounds.maxY - anchor.inset + widgetOffset
		let placementSignature = [
			String(describing: ObjectIdentifier(container)),
			String(Int((targetBottom * 2).rounded())),
			String(Int((frame.minX * 2).rounded())),
			String(Int((frame.minY * 2).rounded())),
			String(Int((frame.width * 2).rounded())),
			String(Int((frame.height * 2).rounded())),
		].joined(separator: "|")
		let lastApplied =
			(objc_getAssociatedObject(view, &posterBoardAppliedTransformKey) as? NSValue)?
			.cgAffineTransformValue
		let lastPlacementSignature =
			objc_getAssociatedObject(view, &posterBoardPlacementSignatureKey) as? String
		if let lastApplied,
			view.transform == lastApplied,
			lastPlacementSignature == placementSignature
		{
			return
		}

		PosterBoardDebugLog.emit(
			"apply-entered",
			every: 1,
			"apply entered target=\(PosterBoardDebugLog.describe(view)) "
				+ "container=\(PosterBoardDebugLog.describe(container))"
		)
		let baseTransform = posterBoardBaseTransform(for: view)
		setPosterBoardTransform(baseTransform, on: view)

		let deltaY = targetBottom - frame.maxY
		guard deltaY.isFinite, abs(deltaY) <= max(container.bounds.height * 1.5, 240) else {
			PosterBoardDebugLog.emit(
				"apply-delta-gate",
				every: 1,
				"apply rejected frameMaxY=\(frame.maxY) targetBottom=\(targetBottom) "
					+ "deltaY=\(deltaY) containerHeight=\(container.bounds.height)"
			)
			return
		}

		var appliedTransform = baseTransform
		appliedTransform.ty += deltaY
		objc_setAssociatedObject(
			view,
			&posterBoardComplicationTransformOffsetKey,
			NSNumber(value: Double(deltaY)),
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
		PosterBoardDebugLog.emit(
			"apply-geometry",
			every: 1,
			"apply geometry frame=\(PosterBoardDebugLog.rect(frame)) targetBottom=\(targetBottom) "
				+ "anchorMode=\(anchor.mode) anchorInset=\(anchor.inset) "
				+ "widgetOffset=\(widgetOffset) "
				+ "deltaY=\(deltaY) localDelta=(0.0,\(deltaY)) "
				+ "base=\(PosterBoardDebugLog.transform(baseTransform)) "
				+ "applied=\(PosterBoardDebugLog.transform(appliedTransform))"
		)

		if view.transform != appliedTransform {
			setPosterBoardTransform(appliedTransform, on: view)
		}
		objc_setAssociatedObject(
			view,
			&posterBoardAppliedTransformKey,
			NSValue(cgAffineTransform: appliedTransform),
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
		objc_setAssociatedObject(
			view,
			&posterBoardPlacementSignatureKey,
			placementSignature,
			.OBJC_ASSOCIATION_COPY_NONATOMIC
		)
		PosterBoardDebugLog.emit(
			"apply-complete",
			every: 1,
			"apply complete current=\(PosterBoardDebugLog.transform(view.transform)) "
				+ PosterBoardDebugLog.describe(view)
		)
		schedulePosterBoardPositionVerification(
			view,
			container: container,
			expectedTransform: appliedTransform
		)
	}

	static func schedulePosterBoardPositionVerification(
		_ view: UIView,
		container: UIView,
		expectedTransform: CGAffineTransform
	) {
		let generation =
			((objc_getAssociatedObject(view, &posterBoardVerificationGenerationKey) as? NSNumber)?
				.intValue ?? 0) + 1
		objc_setAssociatedObject(
			view,
			&posterBoardVerificationGenerationKey,
			NSNumber(value: generation),
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)

		for delay in [0.05, 0.25, 0.75] {
			DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak view, weak container] in
				guard let view, let container else { return }
				let currentGeneration =
					(objc_getAssociatedObject(view, &posterBoardVerificationGenerationKey)
					as? NSNumber)?.intValue
				guard currentGeneration == generation else { return }

				let currentTransform = view.transform
				let frame = logicalFrameIgnoringTransforms(of: view, in: container) ?? .null
				PosterBoardDebugLog.emit(
					"apply-readback-\(ObjectIdentifier(view))-\(delay)",
					"apply readback +\(delay)s preserved=\(currentTransform == expectedTransform) "
						+ "expected=\(PosterBoardDebugLog.transform(expectedTransform)) "
						+ "current=\(PosterBoardDebugLog.transform(currentTransform)) "
						+ "frame=\(PosterBoardDebugLog.rect(frame)) window=\(view.window != nil)"
				)
			}
		}
	}

	static func logicalFrameIgnoringTransforms(
		of view: UIView,
		in ancestor: UIView
	) -> CGRect? {
		var point = view.bounds.origin
		var cursor = view

		while cursor !== ancestor {
			guard let parent = cursor.superview else { return nil }
			let bounds = cursor.bounds
			let anchorPoint = cursor.layer.anchorPoint
			let logicalOrigin = CGPoint(
				x: cursor.layer.position.x - anchorPoint.x * bounds.width,
				y: cursor.layer.position.y - anchorPoint.y * bounds.height
			)
			point.x = logicalOrigin.x + point.x - bounds.origin.x
			point.y = logicalOrigin.y + point.y - bounds.origin.y
			cursor = parent
		}

		return CGRect(origin: point, size: view.bounds.size)
	}

	static func setPosterBoardTransform(
		_ transform: CGAffineTransform,
		on view: UIView
	) {
		CATransaction.begin()
		CATransaction.setDisableActions(true)
		view.layer.setAffineTransform(transform)
		CATransaction.commit()
	}

	static func posterBoardBaseTransform(for view: UIView) -> CGAffineTransform {
		let storedBase = (objc_getAssociatedObject(view, &posterBoardBaseTransformKey) as? NSValue)?
			.cgAffineTransformValue
		let lastApplied =
			(objc_getAssociatedObject(view, &posterBoardAppliedTransformKey) as? NSValue)?
			.cgAffineTransformValue

		if let storedBase, let lastApplied,
			view.transform == lastApplied
		{
			return storedBase
		}

		let baseTransform = view.transform
		objc_setAssociatedObject(
			view,
			&posterBoardBaseTransformKey,
			NSValue(cgAffineTransform: baseTransform),
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
		objc_setAssociatedObject(
			view,
			&posterBoardAppliedTransformKey,
			nil,
			.OBJC_ASSOCIATION_ASSIGN
		)
		return baseTransform
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

		let baseTransform =
			(objc_getAssociatedObject(view, &posterBoardBaseTransformKey) as? NSValue)?
			.cgAffineTransformValue
		let lastApplied =
			(objc_getAssociatedObject(view, &posterBoardAppliedTransformKey) as? NSValue)?
			.cgAffineTransformValue
		if lastApplied != nil {
			PosterBoardDebugLog.emit(
				"restore-position",
				every: 1,
				"restore requested current=\(PosterBoardDebugLog.transform(view.transform)) "
					+ "base=\(baseTransform.map(PosterBoardDebugLog.transform) ?? "nil") "
					+ "lastApplied=\(lastApplied.map(PosterBoardDebugLog.transform) ?? "nil")"
			)
		}
		objc_setAssociatedObject(
			view,
			&posterBoardComplicationTransformOffsetKey,
			nil,
			.OBJC_ASSOCIATION_ASSIGN
		)
		if let baseTransform, let lastApplied, view.transform == lastApplied {
			setPosterBoardTransform(baseTransform, on: view)
		}

		objc_setAssociatedObject(
			view,
			&posterBoardBaseTransformKey,
			nil,
			.OBJC_ASSOCIATION_ASSIGN
		)
		objc_setAssociatedObject(
			view,
			&posterBoardAppliedTransformKey,
			nil,
			.OBJC_ASSOCIATION_ASSIGN
		)
		objc_setAssociatedObject(
			view,
			&posterBoardPlacementSignatureKey,
			nil,
			.OBJC_ASSOCIATION_ASSIGN
		)
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
