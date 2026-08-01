//
//  NSScreen+UUID.swift
//  NotchUI
//

import AppKit
import CoreGraphics

extension NSScreen {
    /// Returns a persistent UUID for this display
    public var displayUUID: String? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        let displayID = CGDirectDisplayID(number.uint32Value)
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID) else {
            // Fallback for displays that do not provide a UUID (e.g. Sidecar, DisplayLink, some docks)
            return String(displayID)
        }
        let uuidString = CFUUIDCreateString(nil, uuid.takeRetainedValue()) as String
        return uuidString
    }

    /// Find a screen by its UUID
    @MainActor public static func screen(withUUID uuid: String) -> NSScreen? {
        return ScreenDisplayRegistry.shared.screen(forUUID: uuid)
    }

    /// Get UUID to NSScreen mapping for all screens
    @MainActor public static var screensByUUID: [String: NSScreen] {
        return ScreenDisplayRegistry.shared.screensByUUID
    }
}
