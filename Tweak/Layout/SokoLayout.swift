import Darwin
import ObjectiveC.runtime
import UIKit

enum SokoLayout {
	typealias MediaRemoteExpandedPlatterGetter = @convention(c) () -> Bool

	static let isPosterBoardProcess =
		Bundle.main.bundleIdentifier == "com.apple.PosterBoard"

	static var cachedMediaRemoteExpandedPlatterGetter: MediaRemoteExpandedPlatterGetter?
	static var mediaRemoteExpandedPlatterGetter: MediaRemoteExpandedPlatterGetter? {
		if let cachedMediaRemoteExpandedPlatterGetter {
			return cachedMediaRemoteExpandedPlatterGetter
		}

		guard
			let symbol = dlsym(
				UnsafeMutableRawPointer(bitPattern: -2),
				"MRPrefersExpandedLockScreenPlatter"
			)
		else { return nil }
		let getter = unsafeBitCast(symbol, to: MediaRemoteExpandedPlatterGetter.self)
		cachedMediaRemoteExpandedPlatterGetter = getter
		return getter
	}

	static var notificationListClass: AnyClass? {
		objc_getClass("NCNotificationListView") as? AnyClass
	}

	static var prominentViewClass: AnyClass? {
		objc_getClass("CSProminentEmptyElementView") as? AnyClass
	}

	static var prominentDisplayViewClass: AnyClass? {
		objc_getClass("CSProminentDisplayView") as? AnyClass
	}

	static var usesIOS16ProminentDisplayCompatibility: Bool {
		Bundle.main.bundleIdentifier == "com.apple.springboard"
			&& ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 16
	}

	static var quickActionsViewClass: AnyClass? {
		objc_getClass("CSQuickActionsView") as? AnyClass
	}

	static var quickActionsButtonClass: AnyClass? {
		objc_getClass("CSQuickActionsButton") as? AnyClass
	}

	static var coverSheetViewBaseClass: AnyClass? {
		objc_getClass("CSCoverSheetViewBase") as? AnyClass
	}

	static var notificationCountIndicatorClass: AnyClass? {
		objc_getClass("NCNotificationListCountIndicatorView") as? AnyClass
	}

	static var combinedListViewControllerClass: AnyClass? {
		objc_getClass("CSCombinedListViewController") as? AnyClass
	}

	static var posterBoardHitTestingViewClass: AnyClass? {
		objc_getClass("PRSubviewHitTestingView") as? AnyClass
	}

	static var posterBoardWidgetGridControllerClasses: [AnyClass] {
		let classNames: [String] = [
			"PRGraphicComplicationContainerViewController",
			"PRWidgetGridViewController",
		]
		return classNames.compactMap { objc_getClass($0) as? AnyClass }
	}

	static func isPosterBoardWidgetGridController(
		_ controller: UIViewController
	) -> Bool {
		posterBoardWidgetGridControllerClasses.contains {
			controller.isKind(of: $0)
		}
	}

	static func refreshVisibleViews() {
		let windows = posterBoardWindows()
		if isPosterBoardProcess {
			PosterBoardDebugLog.emit(
				"refresh-visible-views",
				every: 5,
				"refreshVisibleViews windows=\(windows.count)"
			)
		}
		if usesIOS16ProminentDisplayCompatibility {
			PosterBoardDebugLog.emit(
				"ios16-refresh-visible-views",
				every: 1,
				"iOS 16 SpringBoard refreshVisibleViews windows=\(windows.count)"
			)
		}

		for window in windows {
			if usesIOS16ProminentDisplayCompatibility,
				let prominentDisplayViewClass
			{
				let displays = descendants(of: prominentDisplayViewClass, under: window)
				PosterBoardDebugLog.emit(
					"ios16-prominent-display-count-\(ObjectIdentifier(window))",
					every: 1,
					"iOS 16 SpringBoard window=\(NSStringFromClass(type(of: window))) "
						+ "prominentDisplayCount=\(displays.count)"
				)
				for display in displays {
					handleProminentDisplayLayout(display, force: true)
				}
			}

			if let prominentViewClass {
				let widgets = descendants(of: prominentViewClass, under: window)
				if isPosterBoardProcess {
					PosterBoardDebugLog.emit(
						"refresh-prominent-count",
						every: 1,
						"window=\(NSStringFromClass(type(of: window))) "
							+ "prominentCount=\(widgets.count)"
					)
				}
				for widget in widgets {
					scheduleWidgetRelayout(widget)
				}
			}

			guard let notificationListClass else { continue }
			for list in descendants(of: notificationListClass, under: window) {
				relayoutNotificationList(list)
			}
		}
	}

	static func posterBoardWindows() -> [UIWindow] {
		let sceneWindows = UIApplication.shared.connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.flatMap(\.windows)
		var windows: [UIWindow] = []
		var identifiers = Set<ObjectIdentifier>()
		for window in UIApplication.shared.windows + sceneWindows {
			if identifiers.insert(ObjectIdentifier(window)).inserted {
				windows.append(window)
			}
		}
		return windows
	}

}
