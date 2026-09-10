import ObjectiveC.runtime
import UIKit

extension SokoLayout {
	static func scheduleWidgetRelayout(_ widget: UIView) {
		guard widget.window != nil else { return }
		guard !associatedBool(for: widget, key: &widgetRelayoutPendingKey) else { return }

		setAssociatedBool(true, for: widget, key: &widgetRelayoutPendingKey)
		DispatchQueue.main.async {
			setAssociatedBool(false, for: widget, key: &widgetRelayoutPendingKey)
			guard widget.window != nil else { return }
			relayoutWidget(widget)
		}
	}

	static func handleProminentDisplayLayout(
		_ display: UIView,
		force: Bool = false
	) {
		guard usesIOS16ProminentDisplayCompatibility else { return }
		guard let row = prominentDisplayComplicationRow(in: display) else {
			return
		}

		let usesEditingLayout = prominentDisplayUsesEditingLayout(display)

		if usesEditingLayout {
			objc_setAssociatedObject(
				row,
				&knownComplicationRowRelayoutPendingKey,
				nil,
				.OBJC_ASSOCIATION_ASSIGN
			)
			restoreWidgetConstraints(row)
			objc_setAssociatedObject(
				display,
				&prominentDisplayLastComplicationRowKey,
				nil,
				.OBJC_ASSOCIATION_ASSIGN
			)
			return
		}

		guard row.window != nil else { return }
		let lastRow =
			objc_getAssociatedObject(
				display,
				&prominentDisplayLastComplicationRowKey
			) as? UIView
		let placementConstraints =
			objc_getAssociatedObject(
				row,
				&widgetConstraintsKey
			) as? [NSLayoutConstraint] ?? []
		let hasActivePlacement =
			!placementConstraints.isEmpty
			&& placementConstraints.allSatisfy(\.isActive)
		let heightChanged =
			complicationContainerHeight().map { height in
				guard
					let placedHeight = placementConstraints.first(where: {
						$0.firstAttribute == .height
					})
				else { return true }
				return abs(placedHeight.constant - height) > 0.01
			} ?? false
		if hasActivePlacement && !heightChanged {
			synchronizeWidgetPlacement(row, constraints: placementConstraints)
		}
		let shouldSchedule = force || lastRow !== row || !hasActivePlacement || heightChanged
		guard shouldSchedule else { return }

		objc_setAssociatedObject(
			display,
			&prominentDisplayLastComplicationRowKey,
			row,
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
		scheduleKnownComplicationRowRelayout(row, in: display)
	}

	static func prominentDisplayComplicationRow(in display: UIView) -> UIView? {
		let selector = NSSelectorFromString("complicationRowView")
		guard display.responds(to: selector) else { return nil }
		return display.perform(selector)?.takeUnretainedValue() as? UIView
	}

	static func prominentDisplayUsesEditingLayout(_ display: UIView) -> Bool {
		let selector = NSSelectorFromString("usesEditingLayout")
		guard display.responds(to: selector) else { return false }

		typealias Getter = @convention(c) (UIView, Selector) -> Bool
		let getter = unsafeBitCast(display.method(for: selector), to: Getter.self)
		return getter(display, selector)
	}

	static func scheduleKnownComplicationRowRelayout(_ widget: UIView, in display: UIView) {
		guard widget.window != nil else { return }
		guard objc_getAssociatedObject(widget, &knownComplicationRowRelayoutPendingKey) == nil
		else { return }

		let request = NSObject()
		objc_setAssociatedObject(
			widget,
			&knownComplicationRowRelayoutPendingKey,
			request,
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
		DispatchQueue.main.async { [weak widget, weak display] in
			guard let widget,
				objc_getAssociatedObject(widget, &knownComplicationRowRelayoutPendingKey)
					as? NSObject === request
			else { return }
			defer {
				if objc_getAssociatedObject(widget, &knownComplicationRowRelayoutPendingKey)
					as? NSObject === request
				{
					objc_setAssociatedObject(
						widget,
						&knownComplicationRowRelayoutPendingKey,
						nil,
						.OBJC_ASSOCIATION_ASSIGN
					)
				}
			}
			guard let display, widget.window != nil,
				widget.window === display.window,
				widget.isDescendant(of: display),
				prominentDisplayComplicationRow(in: display) === widget,
				!prominentDisplayUsesEditingLayout(display)
			else { return }
			relayoutWidget(widget, isKnownComplicationRow: true)
		}
	}

	static func relayoutWidget(
		_ widget: UIView,
		isKnownComplicationRow: Bool = false
	) {
		if isPosterBoardProcess {
			relayoutPosterBoardProminentWidget(widget)
			return
		}

		guard let window = widget.window else { return }
		if usesIOS16ProminentDisplayCompatibility,
			let displayClass = prominentDisplayViewClass,
			let display = ancestor(of: widget, matching: displayClass),
			prominentDisplayUsesEditingLayout(display)
		{
			restoreWidgetConstraints(widget)
			return
		}
		guard isKnownComplicationRow || widget === bottomProminentView(in: window) else {
			restoreWidgetConstraints(widget)
			return
		}

		let complicationHeight: CGFloat?
		if usesIOS16ProminentDisplayCompatibility,
			isKnownComplicationRow
				|| (prominentDisplayViewClass.flatMap { ancestor(of: widget, matching: $0) }
					.flatMap { prominentDisplayComplicationRow(in: $0) } === widget)
		{
			complicationHeight = complicationContainerHeight()
		} else {
			complicationHeight = nil
		}

		let quickActions = quickActionsView(for: widget)
		let quickActionButton: UIView?
		if let quickActions,
			let buttonClass = quickActionsButtonClass
		{
			quickActionButton = firstVisibleDescendant(of: buttonClass, under: quickActions)
		} else {
			quickActionButton = nil
		}

		if window.safeAreaInsets.bottom > 0.5, quickActionButton == nil {
			return
		}

		let container: UIView
		if let quickActions, quickActionButton != nil {
			guard let commonContainer = commonAncestor(of: widget, and: quickActions) else {
				return
			}
			container = commonContainer
		} else {
			container = lockScreenContainer(for: widget) ?? window
		}

		let sizeBeforeRestore = widget.bounds.size
		restoreWidgetConstraints(widget)

		let preservedWidgetSize: CGSize?
		if quickActionButton == nil || complicationHeight != nil {
			container.layoutIfNeeded()
			let measuredWidth = max(sizeBeforeRestore.width, widget.bounds.width)
			let measuredHeight = max(sizeBeforeRestore.height, widget.bounds.height)
			let fallbackWidth = max(
				0,
				container.bounds.width - (widgetRowHorizontalPadding * 2)
			)
			let preservedWidth = measuredWidth >= 100 ? measuredWidth : fallbackWidth
			let preservedHeight =
				complicationHeight
				?? (measuredHeight >= 20
					? measuredHeight
					: widgetRowFallbackHeight)
			preservedWidgetSize = CGSize(
				width: preservedWidth,
				height: preservedHeight
			)
		} else {
			preservedWidgetSize = nil
		}

		suppressVerticalConstraints(for: widget, replacingHeight: complicationHeight != nil)
		widget.translatesAutoresizingMaskIntoConstraints = false

		let verticalConstraint: NSLayoutConstraint
		if let button = quickActionButton {
			verticalConstraint = widget.bottomAnchor.constraint(
				equalTo: button.topAnchor,
				constant: CGFloat(TweakPreferences.shared.preferences.widgetOffset)
			)
		} else {
			let bottomInset = max(widgetBottomEdgePadding, container.safeAreaInsets.bottom)
			let widgetOffset = CGFloat(TweakPreferences.shared.preferences.widgetOffset)
			verticalConstraint = widget.bottomAnchor.constraint(
				equalTo: container.bottomAnchor,
				constant: widgetOffset - bottomInset
			)
		}

		var constraints = [
			widget.centerXAnchor.constraint(equalTo: container.centerXAnchor),
			verticalConstraint,
		]
		if let preservedWidgetSize {
			constraints.append(
				contentsOf: [
					widget.widthAnchor.constraint(
						equalToConstant: preservedWidgetSize.width
					),
					widget.heightAnchor.constraint(
						equalToConstant: preservedWidgetSize.height
					),
				]
			)
		}
		NSLayoutConstraint.activate(constraints)
		objc_setAssociatedObject(
			widget,
			&widgetConstraintsKey,
			constraints,
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)

		if usesIOS16ProminentDisplayCompatibility {
			synchronizeWidgetPlacement(widget, constraints: constraints)
		}
		if complicationHeight != nil {
			widget.setNeedsLayout()
			container.layoutIfNeeded()
			widget.layoutIfNeeded()
		}
		refreshNotificationLists(in: widget.window)
	}
}
