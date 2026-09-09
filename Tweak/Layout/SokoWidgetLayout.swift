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
			PosterBoardDebugLog.emit(
				"ios16-prominent-row-missing-\(ObjectIdentifier(display))",
				every: 1,
				"iOS 16 prominent display has no complicationRowView "
					+ PosterBoardDebugLog.describe(display)
			)
			return
		}

		let usesEditingLayout = prominentDisplayUsesEditingLayout(display)
		PosterBoardDebugLog.emit(
			"ios16-prominent-row-state-\(ObjectIdentifier(display))",
			every: 1,
			"iOS 16 prominent display editing=\(usesEditingLayout) "
				+ "display=\(PosterBoardDebugLog.describe(display)) "
				+ "row=\(PosterBoardDebugLog.describe(row))"
		)

		if usesEditingLayout {
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
		let hasActivePlacement = !placementConstraints.isEmpty
			&& placementConstraints.allSatisfy(\.isActive)
		if hasActivePlacement {
			synchronizeButtonlessWidgetPlacement(row, constraints: placementConstraints)
		}
		let shouldSchedule = force || lastRow !== row || !hasActivePlacement
		guard shouldSchedule else { return }

		objc_setAssociatedObject(
			display,
			&prominentDisplayLastComplicationRowKey,
			row,
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		)
		scheduleKnownComplicationRowRelayout(row)
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

	static func scheduleKnownComplicationRowRelayout(_ widget: UIView) {
		guard widget.window != nil else { return }
		guard
			!associatedBool(
				for: widget,
				key: &knownComplicationRowRelayoutPendingKey
			)
		else { return }

		setAssociatedBool(
			true,
			for: widget,
			key: &knownComplicationRowRelayoutPendingKey
		)
		DispatchQueue.main.async {
			defer {
				setAssociatedBool(
					false,
					for: widget,
					key: &knownComplicationRowRelayoutPendingKey
				)
			}
			guard widget.window != nil else { return }
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
		guard isKnownComplicationRow || widget === bottomProminentView(in: window) else {
			restoreWidgetConstraints(widget)
			return
		}

		let quickActions = quickActionsView(near: widget)
		let quickActionButton: UIView?
		if let quickActions,
			!quickActions.isHidden,
			quickActions.alpha > 0.01,
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

		let preservedButtonlessSize: CGSize?
		if quickActionButton == nil {
			container.layoutIfNeeded()
			let measuredWidth = max(sizeBeforeRestore.width, widget.bounds.width)
			let measuredHeight = max(sizeBeforeRestore.height, widget.bounds.height)
			let fallbackWidth = max(
				0,
				container.bounds.width - (widgetRowHorizontalPadding * 2)
			)
			let preservedWidth = measuredWidth >= 100 ? measuredWidth : fallbackWidth
			let preservedHeight =
				measuredHeight >= 20
				? measuredHeight
				: widgetRowFallbackHeight
			preservedButtonlessSize = CGSize(
				width: preservedWidth,
				height: preservedHeight
			)
		} else {
			preservedButtonlessSize = nil
		}

		suppressVerticalConstraints(for: widget)
		widget.translatesAutoresizingMaskIntoConstraints = false

		let verticalConstraint: NSLayoutConstraint
		if let button = quickActionButton {
			let buttonFrame = container.convert(button.bounds, from: button)
			PosterBoardDebugLog.emit(
				"lockscreen-widget-anchor",
				every: 1,
				"lockscreen widget anchor containerHeight=\(container.bounds.height) "
					+ "quickActionTop=\(buttonFrame.minY) "
					+ "quickActionTopInset=\(container.bounds.maxY - buttonFrame.minY) "
					+ "widgetOffset=\(TweakPreferences.shared.preferences.widgetOffset)"
			)
			verticalConstraint = widget.bottomAnchor.constraint(
				equalTo: button.topAnchor,
				constant: CGFloat(TweakPreferences.shared.preferences.widgetOffset)
			)
		} else {
			let bottomInset = max(widgetBottomEdgePadding, container.safeAreaInsets.bottom)
			let widgetOffset = CGFloat(TweakPreferences.shared.preferences.widgetOffset)
			PosterBoardDebugLog.emit(
				"lockscreen-widget-bottom-anchor",
				every: 1,
				"lockscreen widget screen-bottom anchor containerHeight=\(container.bounds.height) "
					+ "safeAreaBottom=\(container.safeAreaInsets.bottom) "
					+ "bottomInset=\(bottomInset) widgetOffset=\(widgetOffset)"
			)
			verticalConstraint = widget.bottomAnchor.constraint(
				equalTo: container.bottomAnchor,
				constant: widgetOffset - bottomInset
			)
		}

		var constraints = [
			widget.centerXAnchor.constraint(equalTo: container.centerXAnchor),
			verticalConstraint,
		]
		if let preservedButtonlessSize {
			constraints.append(
				contentsOf: [
					widget.widthAnchor.constraint(
						equalToConstant: preservedButtonlessSize.width
					),
					widget.heightAnchor.constraint(
						equalToConstant: preservedButtonlessSize.height
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
			synchronizeButtonlessWidgetPlacement(widget, constraints: constraints)
		}
	}

}
