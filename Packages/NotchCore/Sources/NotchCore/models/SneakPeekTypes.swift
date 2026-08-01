//
//  SneakPeekTypes.swift
//  machNotch
//
//  Domain-layer value types for sneak peek and expanding view state.
//  Must compile without SwiftUI/AppKit (Foundation only).
//

import Foundation
import CoreGraphics

// MARK: - Sneak Content Type

public enum SneakContentType: Sendable {
    case brightness
    case volume
    case backlight
    case music
    case mic
    case battery
    case download

    public var isHUD: Bool {
        switch self {
        case .volume, .brightness, .backlight, .mic: true
        default: false
        }
    }
}

// MARK: - Sneak Peek State

public struct SneakPeekState: Equatable, Sendable {
    public var show: Bool
    public var type: SneakContentType
    public var value: CGFloat
    public var icon: String

    public init(show: Bool = false, type: SneakContentType = .music, value: CGFloat = 0, icon: String = "") {
        self.show = show
        self.type = type
        self.value = value
        self.icon = icon
    }
}

// MARK: - Shared Sneak Peek (XPC decode)

public struct SharedSneakPeek: Codable, Sendable {
    public var show: Bool
    public var type: String
    public var value: String
    public var icon: String

    public init(show: Bool, type: String, value: String, icon: String) {
        self.show = show
        self.type = type
        self.value = value
        self.icon = icon
    }
}

// MARK: - Expanding View

public enum BrowserType: Sendable {
    case chromium
    case safari
}

public struct ExpandedItem: Equatable, Sendable {
    public var show: Bool
    public var type: SneakContentType
    public var value: CGFloat
    public var browser: BrowserType

    public init(show: Bool = false, type: SneakContentType = .battery, value: CGFloat = 0, browser: BrowserType = .chromium) {
        self.show = show
        self.type = type
        self.value = value
        self.browser = browser
    }
}
