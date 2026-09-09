import UIKit

extension SokoLayout {
	static func synchronizeButtonlessWidgetPlacement(
		_ widget: UIView,
		constraints: [NSLayoutConstraint]
	) {
		guard widget.window != nil,
			constraints.count == 4,
			constraints.allSatisfy(\.isActive),
			let bottom = constraints.first(where: { $0.firstAttribute == .bottom }),
			bottom.firstItem as? UIView === widget,
			bottom.secondAttribute == .bottom,
			let container = bottom.secondItem as? UIView,
			let horizontal = constraints.first(where: { $0.firstAttribute == .centerX }),
			horizontal.secondItem as? UIView === container,
			let width = constraints.first(where: { $0.firstAttribute == .width }),
			let height = constraints.first(where: { $0.firstAttribute == .height }),
			width.constant > 0, height.constant > 0,
			let frame = logicalFrameIgnoringTransforms(of: widget, in: container)
		else { return }

		let targetBottom = container.bounds.maxY + bottom.constant
		let targetCenterX = container.bounds.midX + horizontal.constant
		let anchor = widget.layer.anchorPoint
		let delta = CGPoint(
			x: targetCenterX - width.constant / 2 + anchor.x * width.constant
				- (frame.minX + anchor.x * frame.width),
			y: targetBottom - height.constant + anchor.y * height.constant
				- (frame.minY + anchor.y * frame.height)
		)
		guard delta.x.isFinite, delta.y.isFinite else { return }
		let size = CGSize(width: width.constant, height: height.constant)
		guard abs(delta.x) > 0.01 || abs(delta.y) > 0.01 || widget.bounds.size != size
		else { return }

		CATransaction.begin()
		CATransaction.setDisableActions(true)
		widget.bounds.size = size
		widget.layer.position.x += delta.x
		widget.layer.position.y += delta.y
		CATransaction.commit()

		PosterBoardDebugLog.emit(
			"ios16-buttonless-placement-\(ObjectIdentifier(widget))",
			every: 1,
			"iOS 16 repaired buttonless placement previousBottom=\(frame.maxY) "
				+ "targetBottom=\(targetBottom) deltaY=\(delta.y) "
				+ "row=\(PosterBoardDebugLog.describe(widget))"
		)
	}
}
