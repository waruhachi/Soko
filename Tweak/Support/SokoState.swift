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
var posterBoardProminentPositionOffsetKey: UInt8 = 0
var posterBoardProminentAppliedPositionKey: UInt8 = 0
var posterBoardProminentRelayoutInProgressKey: UInt8 = 0
