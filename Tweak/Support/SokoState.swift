import Darwin
import UIKit

let notificationMinHeight: CGFloat = 120
let widgetBottomEdgePadding: CGFloat = 16
let widgetRowHorizontalPadding: CGFloat = 26
let widgetRowFallbackHeight: CGFloat = 68
let quickActionScreenAspectRatioThreshold: CGFloat = 2
let posterBoardQuickActionTopInset: CGFloat = 118

var widgetConstraintsKey: UInt8 = 0
var widgetSuppressedConstraintsKey: UInt8 = 0
var widgetRelayoutPendingKey: UInt8 = 0
var knownComplicationRowRelayoutPendingKey: UInt8 = 0
var prominentDisplayLastComplicationRowKey: UInt8 = 0
var notificationRelayoutPendingKey: UInt8 = 0
var notificationSystemFrameKey: UInt8 = 0
var notificationAppliedFrameKey: UInt8 = 0
var notificationCountIndicatorAligningKey: UInt8 = 0
var notificationCountIndicatorSystemCenterKey: UInt8 = 0
var notificationCountIndicatorAppliedCenterKey: UInt8 = 0
var mediaControlsLayoutSynchronizingKey: UInt8 = 0
var mediaControlsExpandedStateKey: UInt8 = 0
var posterBoardBaseTransformKey: UInt8 = 0
var posterBoardAppliedTransformKey: UInt8 = 0
var posterBoardComplicationTransformOffsetKey: UInt8 = 0
var posterBoardComplicationRelayoutInProgressKey: UInt8 = 0
var posterBoardRelayoutPendingKey: UInt8 = 0
var posterBoardVerificationGenerationKey: UInt8 = 0
var posterBoardPlacementSignatureKey: UInt8 = 0
var posterBoardProminentPositionOffsetKey: UInt8 = 0
var posterBoardProminentAppliedPositionKey: UInt8 = 0
var posterBoardProminentRelayoutInProgressKey: UInt8 = 0

enum SokoLog {
	static func emit(_ message: @autoclosure () -> String) {
		let renderedMessage = message()
		NSLog("%@", renderedMessage)
		#if DEBUG
			appendToDebugFile(renderedMessage)
		#endif
	}

	#if DEBUG
		private static let debugLogPath = "/tmp/soko.log"

		private static func appendToDebugFile(_ message: String) {
			let timestamp = String(format: "%.3f", Date().timeIntervalSince1970)
			let process = ProcessInfo.processInfo.processName
			let line = "\(timestamp) [\(process):\(getpid())] \(message)\n"
			let fileDescriptor = Darwin.open(
				debugLogPath,
				O_WRONLY | O_CREAT | O_APPEND,
				mode_t(0o644)
			)
			guard fileDescriptor >= 0 else { return }
			defer { Darwin.close(fileDescriptor) }

			let bytes = Array(line.utf8)
			bytes.withUnsafeBytes { buffer in
				guard let baseAddress = buffer.baseAddress else { return }
				var totalWritten = 0
				while totalWritten < buffer.count {
					let result = Darwin.write(
						fileDescriptor,
						baseAddress.advanced(by: totalWritten),
						buffer.count - totalWritten
					)
					guard result > 0 else { return }
					totalWritten += result
				}
			}
		}
	#endif
}

enum PosterBoardDebugLog {
	private static let prefix = "[SokoDebug-PB]"
	private static let lock = NSLock()
	private static var lastEmission: [String: TimeInterval] = [:]

	static func emit(
		_ key: String,
		every minimumInterval: TimeInterval = 0,
		_ message: @autoclosure () -> String
	) {
		let now = ProcessInfo.processInfo.systemUptime
		lock.lock()
		let previous = lastEmission[key]
		if let previous, minimumInterval > 0, now - previous < minimumInterval {
			lock.unlock()
			return
		}
		lastEmission[key] = now
		lock.unlock()

		SokoLog.emit("\(prefix) \(message())")
	}

	static func describe(_ view: UIView?) -> String {
		guard let view else { return "view=nil" }
		let pointer = String(describing: Unmanaged.passUnretained(view).toOpaque())
		return "\(NSStringFromClass(type(of: view)))@\(pointer) "
			+ "frame=\(rect(view.frame)) bounds=\(rect(view.bounds)) "
			+ "window=\(view.window != nil) hidden=\(view.isHidden) alpha=\(view.alpha)"
	}

	static func rect(_ value: CGRect) -> String {
		"(x:\(value.origin.x),y:\(value.origin.y),w:\(value.size.width),h:\(value.size.height))"
	}

	static func transform(_ value: CGAffineTransform) -> String {
		"(a:\(value.a),b:\(value.b),c:\(value.c),d:\(value.d),tx:\(value.tx),ty:\(value.ty))"
	}
}
