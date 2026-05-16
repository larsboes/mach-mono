//
//  NotchGeometry.swift
//  machNotch
//
//  Reauthored notch sizing policy for MIT-readiness.
//

import AppKit
import Foundation

struct CornerRadiusInsets {
    var opened: (top: CGFloat, bottom: CGFloat)
    var closed: (top: CGFloat, bottom: CGFloat)
}

enum MusicPlayerImageSizes {
    static let cornerRadiusInset: (opened: CGFloat, closed: CGFloat) = (opened: 13, closed: 4)
    static let size = (opened: CGSize(width: 90, height: 90), closed: CGSize(width: 20, height: 20))
}

enum NotchGeometry {
    static let downloadSneakSize = CGSize(width: 65, height: 1)
    static let batterySneakSize = CGSize(width: 160, height: 1)
    static let shadowPadding: CGFloat = 20
    static let openSize = CGSize(width: 860, height: 250)
    static let windowSize = CGSize(width: openSize.width, height: openSize.height + shadowPadding)
    static let cornerRadiusInsets = CornerRadiusInsets(
        opened: (top: 19, bottom: 24),
        closed: (top: 6, bottom: 14)
    )

    static let fallbackPhysicalNotchWidth: CGFloat = 220
    static let fallbackRealNotchHeight: CGFloat = 38
    static let fallbackMenuBarHeight: CGFloat = 43
    static let fallbackNonNotchLiveHeight: CGFloat = 32

    struct ScreenMetrics: Equatable {
        let frame: CGRect
        let visibleFrame: CGRect
        let safeAreaTop: CGFloat
        let auxiliaryTopLeftWidth: CGFloat?
        let auxiliaryTopRightWidth: CGFloat?

        init(
            frame: CGRect,
            visibleFrame: CGRect,
            safeAreaTop: CGFloat,
            auxiliaryTopLeftWidth: CGFloat? = nil,
            auxiliaryTopRightWidth: CGFloat? = nil
        ) {
            self.frame = frame
            self.visibleFrame = visibleFrame
            self.safeAreaTop = safeAreaTop
            self.auxiliaryTopLeftWidth = auxiliaryTopLeftWidth
            self.auxiliaryTopRightWidth = auxiliaryTopRightWidth
        }

        init(screen: NSScreen) {
            self.init(
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                safeAreaTop: screen.safeAreaInsets.top,
                auxiliaryTopLeftWidth: screen.auxiliaryTopLeftArea?.width,
                auxiliaryTopRightWidth: screen.auxiliaryTopRightArea?.width
            )
        }
    }

    @MainActor static func screen(for uuid: String? = nil) -> NSScreen? {
        guard let uuid else { return .main }
        return NSScreen.screen(withUUID: uuid)
    }

    @MainActor static func frame(for uuid: String? = nil) -> CGRect? {
        screen(for: uuid)?.frame
    }

    @MainActor static func realNotchHeight(screens: [NSScreen] = NSScreen.screens) -> CGFloat {
        realNotchHeight(from: screens.map(ScreenMetrics.init(screen:)))
    }

    @MainActor static func menuBarHeight(screens: [NSScreen] = NSScreen.screens) -> CGFloat {
        menuBarHeight(from: screens.map(ScreenMetrics.init(screen:)))
    }

    @MainActor static func syncHeight(settings: any DisplaySettings) {
        switch settings.notchHeightMode {
        case .matchRealNotchSize:
            let height = realNotchHeight()
            if settings.notchHeight != height {
                settings.notchHeight = height
            }
        case .matchMenuBar:
            let height = menuBarHeight()
            if settings.notchHeight != height {
                settings.notchHeight = height
            }
        case .custom:
            break
        }
    }

    static func realNotchHeight(from screens: [ScreenMetrics]) -> CGFloat {
        screens.first { $0.safeAreaTop > 0 }?.safeAreaTop ?? fallbackRealNotchHeight
    }

    static func menuBarHeight(from screens: [ScreenMetrics]) -> CGFloat {
        guard let notchedScreen = screens.first(where: { $0.safeAreaTop > 0 }) else {
            return fallbackMenuBarHeight
        }
        return notchedScreen.frame.maxY - notchedScreen.visibleFrame.maxY - 1
    }

    static func physicalNotchWidth(metrics: ScreenMetrics?) -> CGFloat {
        guard
            let metrics,
            let left = metrics.auxiliaryTopLeftWidth,
            let right = metrics.auxiliaryTopRightWidth,
            left > 100,
            right > 100
        else {
            return fallbackPhysicalNotchWidth
        }

        return min(openSize.width, max(fallbackPhysicalNotchWidth, metrics.frame.width - left - right + 12))
    }

    @MainActor static func physicalNotchWidth(screen: NSScreen?) -> CGFloat {
        physicalNotchWidth(metrics: screen.map(ScreenMetrics.init(screen:)))
    }

    @MainActor static func closedSize(
        settings: any DisplaySettings,
        screenUUID: String? = nil,
        hasLiveActivity: Bool = false
    ) -> CGSize {
        let screen = screen(for: screenUUID)
        return closedSize(
            settings: settings,
            metrics: screen.map(ScreenMetrics.init(screen:)),
            hasLiveActivity: hasLiveActivity
        )
    }

    @MainActor static func closedSize(
        settings: any DisplaySettings,
        metrics: ScreenMetrics?,
        hasLiveActivity: Bool
    ) -> CGSize {
        CGSize(
            width: physicalNotchWidth(metrics: metrics),
            height: closedHeight(settings: settings, metrics: metrics, hasLiveActivity: hasLiveActivity)
        )
    }

    @MainActor static func inactiveSize(settings: any DisplaySettings, screenUUID: String? = nil) -> CGSize {
        let screen = screen(for: screenUUID)
        return CGSize(width: physicalNotchWidth(screen: screen), height: settings.inactiveNotchHeight)
    }

    @MainActor static func closedHeight(
        settings: any DisplaySettings,
        metrics: ScreenMetrics?,
        hasLiveActivity: Bool
    ) -> CGFloat {
        guard let metrics else { return settings.nonNotchHeight }
        guard metrics.safeAreaTop > 0 else {
            return nonNotchedHeight(settings: settings, metrics: metrics, hasLiveActivity: hasLiveActivity)
        }
        return notchedHeight(settings: settings, metrics: metrics, hasLiveActivity: hasLiveActivity)
    }

    @MainActor private static func notchedHeight(
        settings: any DisplaySettings,
        metrics: ScreenMetrics,
        hasLiveActivity: Bool
    ) -> CGFloat {
        guard hasLiveActivity else { return metrics.safeAreaTop }

        switch settings.notchHeightMode {
        case .matchRealNotchSize:
            return metrics.safeAreaTop
        case .matchMenuBar:
            return metrics.frame.maxY - metrics.visibleFrame.maxY
        case .custom:
            return settings.notchHeight
        }
    }

    @MainActor private static func nonNotchedHeight(
        settings: any DisplaySettings,
        metrics: ScreenMetrics,
        hasLiveActivity: Bool
    ) -> CGFloat {
        switch settings.nonNotchHeightMode {
        case .matchMenuBar:
            return metrics.frame.maxY - metrics.visibleFrame.maxY
        case .matchRealNotchSize:
            return fallbackNonNotchLiveHeight
        case .custom:
            return hasLiveActivity ? fallbackNonNotchLiveHeight : settings.nonNotchHeight
        }
    }

}

let downloadSneakSize = NotchGeometry.downloadSneakSize
let batterySneakSize = NotchGeometry.batterySneakSize
let shadowPadding = NotchGeometry.shadowPadding
let openNotchSize = NotchGeometry.openSize
let windowSize = NotchGeometry.windowSize
let cornerRadiusInsets = NotchGeometry.cornerRadiusInsets

@MainActor func resolveScreen(_ screenUUID: String? = nil) -> NSScreen? {
    NotchGeometry.screen(for: screenUUID)
}

@MainActor func getScreenFrame(_ screenUUID: String? = nil) -> CGRect? {
    NotchGeometry.frame(for: screenUUID)
}

@MainActor func getRealNotchHeight() -> CGFloat {
    NotchGeometry.realNotchHeight()
}

@MainActor func getMenuBarHeight() -> CGFloat {
    NotchGeometry.menuBarHeight()
}

@MainActor func syncNotchHeightIfNeeded(settings: any DisplaySettings) {
    NotchGeometry.syncHeight(settings: settings)
}

@MainActor func physicalNotchWidth(screen: NSScreen?) -> CGFloat {
    NotchGeometry.physicalNotchWidth(screen: screen)
}

@MainActor func getClosedNotchSize(
    settings: any DisplaySettings,
    screenUUID: String? = nil,
    hasLiveActivity: Bool = false
) -> CGSize {
    NotchGeometry.closedSize(settings: settings, screenUUID: screenUUID, hasLiveActivity: hasLiveActivity)
}

@MainActor func getInactiveNotchSize(settings: any DisplaySettings, screenUUID: String? = nil) -> CGSize {
    NotchGeometry.inactiveSize(settings: settings, screenUUID: screenUUID)
}
