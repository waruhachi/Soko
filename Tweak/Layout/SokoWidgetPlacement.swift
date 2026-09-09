import UIKit

extension SokoLayout {
	static func synchronizeWidgetPlacement(
		_ widget: UIView,
		constraints: [NSLayoutConstraint]
	) {
		guard widget.window != nil,
			(3...4).contains(constraints.count),
			constraints.allSatisfy(\.isActive),
			let bottom = constraints.first(where: { $0.firstAttribute == .bottom }),
			bottom.firstItem as? UIView === widget,
			let bottomReference = bottom.secondItem as? UIView,
			let horizontal = constraints.first(where: { $0.firstAttribute == .centerX }),
			horizontal.firstItem as? UIView === widget,
			let container = horizontal.secondItem as? UIView,
			let height = constraints.first(where: { $0.firstAttribute == .height }),
			height.firstItem as? UIView === widget,
			height.constant.isFinite, height.constant > 0,
			let frame = logicalFrameIgnoringTransforms(of: widget, in: container)
		else { return }

		let targetBottom: CGFloat
		if bottom.secondAttribute == .bottom, bottomReference === container {
			targetBottom = container.bounds.maxY + bottom.constant
		} else if bottom.secondAttribute == .top,
			bottomReference.window === widget.window,
			let referenceFrame = logicalFrameIgnoringTransforms(of: bottomReference, in: container)
		{
			targetBottom = referenceFrame.minY + bottom.constant
		} else {
			return
		}
		let width =
			constraints.first(where: { $0.firstAttribute == .width })?.constant
			?? widget.bounds.width
		guard width.isFinite, width > 0 else { return }
		let targetCenterX = container.bounds.midX + horizontal.constant
		let anchor = widget.layer.anchorPoint
		let delta = CGPoint(
			x: targetCenterX - width / 2 + anchor.x * width
				- (frame.minX + anchor.x * frame.width),
			y: targetBottom - height.constant + anchor.y * height.constant
				- (frame.minY + anchor.y * frame.height)
		)
		guard delta.x.isFinite, delta.y.isFinite else { return }
		let size = CGSize(width: width, height: height.constant)
		guard abs(delta.x) > 0.01 || abs(delta.y) > 0.01 || widget.bounds.size != size
		else { return }

		CATransaction.begin()
		CATransaction.setDisableActions(true)
		widget.bounds.size = size
		widget.layer.position.x += delta.x
		widget.layer.position.y += delta.y
		CATransaction.commit()
		widget.setNeedsLayout()
	}
}
