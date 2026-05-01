//
//  SneakPeekTypes.swift
//  boringNotch
//
//  Domain-layer value types for sneak peek and expanding view state.
//  Must compile without SwiftUI/AppKit (Foundation only).
//

import Foundation

// MARK: - Sneak Content Type

enum SneakContentType {
    case brightness
    case volume
    case backlight
    case music
    case mic
    case battery
    case download

    var isHUD: Bool {
        switch self {
        case .volume, .brightness, .backlight, .mic: true
        default: false
        }
    }
}

// MARK: - Sneak Peek State

struct SneakPeekState: Equatable {
    var show: Bool = false
    var type: SneakContentType = .music
    var value: CGFloat = 0
    var icon: String = ""
}

// MARK: - Shared Sneak Peek (XPC decode)

struct SharedSneakPeek: Codable {
    var show: Bool
    var type: String
    var value: String
    var icon: String
}

// MARK: - Expanding View

enum BrowserType {
    case chromium
    case safari
}

struct ExpandedItem {
    var show: Bool = false
    var type: SneakContentType = .battery
    var value: CGFloat = 0
    var browser: BrowserType = .chromium
}
