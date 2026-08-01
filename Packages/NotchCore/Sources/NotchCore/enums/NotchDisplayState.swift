//
//  NotchDisplayState.swift
//  NotchCore
//

import Foundation
import CoreGraphics

/// Represents what the notch should display at any given moment.
public enum NotchDisplayState: Equatable, Sendable {
    case closed(content: ClosedContent)
    case open(view: NotchViews)
    case helloAnimation
    case sneakPeek(type: SneakContentType, value: CGFloat, icon: String)
    case expanding(type: SneakContentType)

    /// Content displayed when the notch is closed
    public enum ClosedContent: Equatable, Sendable {
        case idle
        case plugin(String)  // Generic plugin content
        case face
        case inlineHUD(type: SneakContentType, value: CGFloat, icon: String)
        case sneakPeek(type: SneakContentType, value: CGFloat, icon: String)
    }
}
