//
//  sizeMatters.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 05/08/24.
//

import Defaults
import Foundation
import SwiftUI

let downloadSneakSize: CGSize = .init(width: 65, height: 1)
let batterySneakSize: CGSize = .init(width: 160, height: 1)

let shadowPadding: CGFloat = 20
let openNotchSize: CGSize = .init(width: 860, height: 250)
let windowSize: CGSize = .init(width: openNotchSize.width, height: openNotchSize.height + shadowPadding)
struct CornerRadiusInsets {
    var opened: (top: CGFloat, bottom: CGFloat)
    var closed: (top: CGFloat, bottom: CGFloat)
}

let cornerRadiusInsets = CornerRadiusInsets(
    opened: (top: 19, bottom: 24),
    closed: (top: 6, bottom: 14)
)

enum MusicPlayerImageSizes {
    static let cornerRadiusInset: (opened: CGFloat, closed: CGFloat) = (opened: 13.0, closed: 4.0)
    static let size = (opened: CGSize(width: 90, height: 90), closed: CGSize(width: 20, height: 20))
}

@MainActor func resolveScreen(_ screenUUID: String? = nil) -> NSScreen? {
    if let uuid = screenUUID { return NSScreen.screen(withUUID: uuid) }
    return .main
}

@MainActor func getScreenFrame(_ screenUUID: String? = nil) -> CGRect? {
    resolveScreen(screenUUID)?.frame
}

@MainActor func getRealNotchHeight() -> CGFloat {
    for screen in NSScreen.screens {
        let safeAreaTop = screen.safeAreaInsets.top
        if safeAreaTop > 0 {
            return safeAreaTop
        }
    }

    return 38
}

@MainActor func getMenuBarHeight() -> CGFloat {
    for screen in NSScreen.screens {
        if screen.safeAreaInsets.top > 0 {
            return screen.frame.maxY - screen.visibleFrame.maxY - 1
        }
    }

    return 43
}

@MainActor func syncNotchHeightIfNeeded(settings: any DisplaySettings) {
    switch settings.notchHeightMode {
    case .matchRealNotchSize:
        let realHeight = getRealNotchHeight()
        if settings.notchHeight != realHeight {
            settings.notchHeight = realHeight
            NotificationCenter.default.post(name: .notchHeightChanged, object: nil)
        }

    case .matchMenuBar:
        let menuHeight = getMenuBarHeight()
        if settings.notchHeight != menuHeight {
            settings.notchHeight = menuHeight
            NotificationCenter.default.post(name: .notchHeightChanged, object: nil)
        }

    case .custom:
        break
    }
}

/// Physical notch width derived from screen auxiliary areas. Falls back to 220px.
@MainActor func physicalNotchWidth(screen: NSScreen?) -> CGFloat {
    guard let screen,
          let left = screen.auxiliaryTopLeftArea?.width,
          let right = screen.auxiliaryTopRightArea?.width,
          left > 100, right > 100 else { return 220 }
    return min(860, max(220, screen.frame.width - left - right + 12))
}

@MainActor func getClosedNotchSize(settings: any DisplaySettings, screenUUID: String? = nil, hasLiveActivity: Bool = false) -> CGSize {
    let screen = resolveScreen(screenUUID)
    let width = physicalNotchWidth(screen: screen)
    let height = closedNotchHeight(screen: screen, settings: settings, hasLiveActivity: hasLiveActivity)
    return CGSize(width: width, height: height)
}

@MainActor func getInactiveNotchSize(settings: any DisplaySettings, screenUUID: String? = nil) -> CGSize {
    let screen = resolveScreen(screenUUID)
    return CGSize(width: physicalNotchWidth(screen: screen), height: settings.inactiveNotchHeight)
}

// MARK: - Height Calculation

@MainActor private func closedNotchHeight(screen: NSScreen?, settings: any DisplaySettings, hasLiveActivity: Bool) -> CGFloat {
    guard let screen else { return settings.nonNotchHeight }

    let hasPhysicalNotch = screen.safeAreaInsets.top > 0

    if hasPhysicalNotch {
        return notchScreenHeight(screen: screen, settings: settings, hasLiveActivity: hasLiveActivity)
    } else {
        return nonNotchScreenHeight(screen: screen, settings: settings, hasLiveActivity: hasLiveActivity)
    }
}

@MainActor private func notchScreenHeight(screen: NSScreen, settings: any DisplaySettings, hasLiveActivity: Bool) -> CGFloat {
    // When idle, strictly match the physical notch to blend in
    guard hasLiveActivity else { return screen.safeAreaInsets.top }

    switch settings.notchHeightMode {
    case .matchRealNotchSize: return screen.safeAreaInsets.top
    case .matchMenuBar:       return screen.frame.maxY - screen.visibleFrame.maxY
    case .custom:             return settings.notchHeight
    }
}

@MainActor private func nonNotchScreenHeight(screen: NSScreen, settings: any DisplaySettings, hasLiveActivity: Bool) -> CGFloat {
    switch settings.nonNotchHeightMode {
    case .matchMenuBar:       return screen.frame.maxY - screen.visibleFrame.maxY
    case .matchRealNotchSize: return 32
    case .custom:             return !hasLiveActivity ? settings.nonNotchHeight : 32
    }
}
