import UIKit

extension SokoLayout {
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
}
