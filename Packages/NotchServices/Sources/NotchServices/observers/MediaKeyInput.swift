//
//  MediaKeyInput.swift
//  machNotch
//
//  Reauthored media-key decoding primitives for MIT-readiness.
//

import AppKit
import Foundation

public enum MediaKeyKind: Int {
    case soundUp = 0
    case soundDown = 1
    case brightnessUp = 2
    case brightnessDown = 3
    case mute = 7
    case keyboardBrightnessUp = 21
    case keyboardBrightnessDown = 22
}

public struct MediaKeyModifiers: Equatable {
    public let option: Bool
    public let shift: Bool
    public let command: Bool

    public init(flags: NSEvent.ModifierFlags) {
        self.option = flags.contains(.option)
        self.shift = flags.contains(.shift)
        self.command = flags.contains(.command)
    }

    public init(option: Bool = false, shift: Bool = false, command: Bool = false) {
        self.option = option
        self.shift = shift
        self.command = command
    }
}

public struct MediaKeyPress: Equatable {
    public let kind: MediaKeyKind
    public let modifiers: MediaKeyModifiers

    public init(kind: MediaKeyKind, modifiers: MediaKeyModifiers) {
        self.kind = kind
        self.modifiers = modifiers
    }

    public var usesFineStep: Bool {
        modifiers.option && modifiers.shift
    }

    public var targetsKeyboardBacklight: Bool {
        switch kind {
        case .keyboardBrightnessUp, .keyboardBrightnessDown:
            return true
        case .brightnessUp, .brightnessDown:
            return modifiers.command
        case .soundUp, .soundDown, .mute:
            return false
        }
    }
}

public enum MediaKeyEventParser {
    public static let systemDefinedSubtype = 8
    public static let keyDownState = 0xA

    public static func press(from event: NSEvent) -> MediaKeyPress? {
        guard event.type == .systemDefined, event.subtype.rawValue == systemDefinedSubtype else {
            return nil
        }

        let keyCode = (event.data1 & 0xFFFF_0000) >> 16
        let state = (event.data1 & 0xFF00) >> 8

        guard state == keyDownState, let kind = MediaKeyKind(rawValue: keyCode) else {
            return nil
        }

        return MediaKeyPress(kind: kind, modifiers: MediaKeyModifiers(flags: event.modifierFlags))
    }
}
