import AppKit
import Foundation
import NotchCore
import MacroVisionKit

extension NotchGeometry.ScreenMetrics {
    public init(screen: NSScreen) {
        self.init(
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryTopLeftWidth: screen.auxiliaryTopLeftArea?.width,
            auxiliaryTopRightWidth: screen.auxiliaryTopRightArea?.width
        )
    }
}

extension NotchGeometry {
    @MainActor public static func screen(for uuid: String? = nil) -> NSScreen? {
        guard let uuid else { return .main }
        return NSScreen.screen(withUUID: uuid)
    }

    @MainActor public static func frame(for uuid: String? = nil) -> CGRect? {
        screen(for: uuid)?.frame
    }

    @MainActor public static func realNotchHeight(screens: [NSScreen] = NSScreen.screens) -> CGFloat {
        realNotchHeight(from: screens.map(ScreenMetrics.init(screen:)))
    }

    @MainActor public static func menuBarHeight(screens: [NSScreen] = NSScreen.screens) -> CGFloat {
        menuBarHeight(from: screens.map(ScreenMetrics.init(screen:)))
    }

    @MainActor public static func syncHeight(settings: any DisplaySettings) {
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

    @MainActor public static func physicalNotchWidth(screen: NSScreen?) -> CGFloat {
        physicalNotchWidth(metrics: screen.map(ScreenMetrics.init(screen:)))
    }

    @MainActor public static func closedSize(
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

    @MainActor public static func inactiveSize(settings: any DisplaySettings, screenUUID: String? = nil) -> CGSize {
        let screen = screen(for: screenUUID)
        return CGSize(width: physicalNotchWidth(screen: screen), height: settings.inactiveNotchHeight)
    }
}

@MainActor public func resolveScreen(_ screenUUID: String? = nil) -> NSScreen? {
    NotchGeometry.screen(for: screenUUID)
}

@MainActor public func getScreenFrame(_ screenUUID: String? = nil) -> CGRect? {
    NotchGeometry.frame(for: screenUUID)
}

@MainActor public func getRealNotchHeight() -> CGFloat {
    NotchGeometry.realNotchHeight()
}

@MainActor public func getMenuBarHeight() -> CGFloat {
    NotchGeometry.menuBarHeight()
}

@MainActor public func syncNotchHeightIfNeeded(settings: any DisplaySettings) {
    NotchGeometry.syncHeight(settings: settings)
}

@MainActor public func physicalNotchWidth(screen: NSScreen?) -> CGFloat {
    NotchGeometry.physicalNotchWidth(screen: screen)
}

@MainActor public func getClosedNotchSize(
    settings: any DisplaySettings,
    screenUUID: String? = nil,
    hasLiveActivity: Bool = false
) -> CGSize {
    NotchGeometry.closedSize(settings: settings, screenUUID: screenUUID, hasLiveActivity: hasLiveActivity)
}

@MainActor public func getInactiveNotchSize(settings: any DisplaySettings, screenUUID: String? = nil) -> CGSize {
    NotchGeometry.inactiveSize(settings: settings, screenUUID: screenUUID)
}
