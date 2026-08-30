import ObjectiveC.runtime
import UIKit

extension SokoLayout {
	static func bottomProminentView(in window: UIWindow) -> UIView? {
		guard let prominentViewClass else { return nil }

		return descendants(of: prominentViewClass, under: window)
			.filter { $0.window != nil && !$0.isHidden && $0.alpha > 0.01 }
			.max { left, right in
				window.convert(left.bounds, from: left).minY
					< window.convert(right.bounds, from: right).minY
			}
	}

	static func quickActionsView(near widget: UIView) -> UIView? {
		guard let quickActionsViewClass else { return nil }

		var cursor: UIView? = widget
		while let view = cursor {
			if let quickActions = firstDescendant(of: quickActionsViewClass, under: view),
				containsQuickActionButton(quickActions)
			{
				return quickActions
			}
			cursor = view.superview
		}

		return nil
	}

	static func lockScreenContainer(for widget: UIView) -> UIView? {
		guard let coverSheetViewBaseClass else { return widget.window }
		return ancestor(of: widget, matching: coverSheetViewBaseClass) ?? widget.window
	}

	static func posterBoardWidgetAnchor(
		for view: UIView
	) -> (inset: CGFloat, mode: String) {
		let screen = view.window?.screen ?? UIScreen.main
		let nativeSize = screen.nativeBounds.size
		let shortSide = min(nativeSize.width, nativeSize.height)
		let longSide = max(nativeSize.width, nativeSize.height)
		let aspectRatio = shortSide > 0 ? longSide / shortSide : 0
		let usesQuickActionLayout =
			UIDevice.current.userInterfaceIdiom == .phone
			&& aspectRatio >= quickActionScreenAspectRatioThreshold
		let anchor =
			usesQuickActionLayout
			? (posterBoardQuickActionTopInset, "quick-actions")
			: (widgetBottomEdgePadding, "screen-bottom")

		#if DEBUG
			PosterBoardDebugLog.emit(
				"editor-anchor-selection",
				every: 1,
				"[DEBUG-soko-editor-anchor] nativeSize=(\(nativeSize.width),\(nativeSize.height)) "
					+ "aspectRatio=\(aspectRatio) "
					+ "windowSafeAreaBottom=\(view.window?.safeAreaInsets.bottom ?? 0) "
					+ "mode=\(anchor.1) inset=\(anchor.0)"
			)
		#endif

		return (anchor.0, anchor.1)
	}

	static func quickActionsView(for view: UIView) -> UIView? {
		guard let quickActionsViewClass else { return nil }

		if let window = view.window,
			let quickActions = firstVisibleDescendant(of: quickActionsViewClass, under: window)
		{
			return quickActions
		}

		var cursor: UIView? = view
		while let ancestor = cursor {
			if let quickActions = firstVisibleDescendant(of: quickActionsViewClass, under: ancestor)
			{
				return quickActions
			}
			cursor = ancestor.superview
		}

		return nil
	}

	static func containsQuickActionButton(_ view: UIView) -> Bool {
		guard let quickActionsButtonClass else { return false }
		return firstDescendant(of: quickActionsButtonClass, under: view) != nil
	}

	static func descendants(of targetClass: AnyClass, under view: UIView) -> [UIView] {
		var matches: [UIView] = []
		collectDescendants(of: targetClass, under: view, into: &matches)
		return matches
	}

	static func collectDescendants(
		of targetClass: AnyClass,
		under view: UIView,
		into matches: inout [UIView]
	) {
		if view.isKind(of: targetClass) {
			matches.append(view)
		}

		for subview in view.subviews {
			collectDescendants(of: targetClass, under: subview, into: &matches)
		}
	}

	static func firstDescendant(of targetClass: AnyClass, under view: UIView) -> UIView? {
		if view.isKind(of: targetClass) {
			return view
		}

		for subview in view.subviews {
			if let match = firstDescendant(of: targetClass, under: subview) {
				return match
			}
		}

		return nil
	}

	static func firstVisibleDescendant(
		of targetClass: AnyClass,
		under view: UIView
	) -> UIView? {
		if view.isKind(of: targetClass), !view.isHidden, view.alpha > 0.01 {
			return view
		}

		for subview in view.subviews {
			if let match = firstVisibleDescendant(of: targetClass, under: subview) {
				return match
			}
		}

		return nil
	}

	static func bottomVisibleDescendant(
		of targetClass: AnyClass,
		under view: UIView
	) -> UIView? {
		guard let reference = view.window else { return nil }

		return descendants(of: targetClass, under: view)
			.filter { !$0.isHidden && $0.alpha > 0.01 }
			.max { left, right in
				reference.convert(left.bounds, from: left).maxY
					< reference.convert(right.bounds, from: right).maxY
			}
	}

	static func commonAncestor(of left: UIView, and right: UIView) -> UIView? {
		var leftAncestors: [UIView] = []
		var cursor: UIView? = left
		while let view = cursor {
			leftAncestors.append(view)
			cursor = view.superview
		}

		cursor = right
		while let view = cursor {
			if leftAncestors.contains(where: { $0 === view }) {
				return view
			}
			cursor = view.superview
		}

		return nil
	}

	static func alignNotificationCountIndicators(in list: UIView) {
		guard let notificationCountIndicatorClass else { return }

		for indicator in descendants(of: notificationCountIndicatorClass, under: list) {
			alignNotificationCountIndicator(indicator)
		}
	}

	static func restoreWidgetConstraints(_ widget: UIView) {
		if let constraints = objc_getAssociatedObject(widget, &widgetConstraintsKey)
			as? [NSLayoutConstraint]
		{
			NSLayoutConstraint.deactivate(constraints)
			objc_setAssociatedObject(widget, &widgetConstraintsKey, nil, .OBJC_ASSOCIATION_ASSIGN)
		}

		if let constraints = objc_getAssociatedObject(widget, &widgetSuppressedConstraintsKey)
			as? [NSLayoutConstraint]
		{
			NSLayoutConstraint.activate(constraints)
			objc_setAssociatedObject(
				widget,
				&widgetSuppressedConstraintsKey,
				nil,
				.OBJC_ASSOCIATION_ASSIGN
			)
		}
	}

	static func suppressVerticalConstraints(for widget: UIView) {
		guard objc_getAssociatedObject(widget, &widgetSuppressedConstraintsKey) == nil else {
			return
		}

		var constraints: [NSLayoutConstraint] = []
		var cursor: UIView? = widget
		while let view = cursor {
			constraints.append(
				contentsOf: view.constraints.filter {
					affectsVerticalPosition($0, of: widget)
				}
			)
			cursor = view.superview
		}

		guard !constraints.isEmpty else { return }
		NSLayoutConstraint.deactivate(constraints)
		objc_setAssociatedObject(
			widget,
			&widgetSuppressedConstraintsKey,
			constraints,
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
	}

	static func affectsVerticalPosition(
		_ constraint: NSLayoutConstraint,
		of widget: UIView
	) -> Bool {
		if constraint.firstItem as? UIView === widget {
			return isVertical(constraint.firstAttribute)
		}

		if constraint.secondItem as? UIView === widget {
			return isVertical(constraint.secondAttribute)
		}

		return false
	}

	static func isVertical(_ attribute: NSLayoutConstraint.Attribute) -> Bool {
		switch attribute {
		case .top, .bottom, .centerY, .firstBaseline, .lastBaseline:
			return true
		default:
			return false
		}
	}

	static func associatedBool(for object: AnyObject, key: UnsafeRawPointer) -> Bool {
		(objc_getAssociatedObject(object, key) as? NSNumber)?.boolValue ?? false
	}

	static func associatedRect(
		for object: AnyObject,
		key: UnsafeRawPointer
	) -> CGRect? {
		(objc_getAssociatedObject(object, key) as? NSValue)?.cgRectValue
	}

	static func setAssociatedRect(
		_ value: CGRect,
		for object: AnyObject,
		key: UnsafeRawPointer
	) {
		objc_setAssociatedObject(
			object,
			key,
			NSValue(cgRect: value),
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
	}

	static func associatedPoint(
		for object: AnyObject,
		key: UnsafeRawPointer
	) -> CGPoint? {
		(objc_getAssociatedObject(object, key) as? NSValue)?.cgPointValue
	}

	static func setAssociatedPoint(
		_ value: CGPoint,
		for object: AnyObject,
		key: UnsafeRawPointer
	) {
		objc_setAssociatedObject(
			object,
			key,
			NSValue(cgPoint: value),
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
	}

	static func setAssociatedBool(
		_ value: Bool,
		for object: AnyObject,
		key: UnsafeRawPointer
	) {
		objc_setAssociatedObject(
			object,
			key,
			NSNumber(value: value),
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
	}
}
