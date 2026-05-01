//
//  Constants.swift
//  boringNotch
//
//  App infrastructure constants — paths, spacing, notification names, data types.
//

import SwiftUI
import Defaults

// MARK: - File System Paths
let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    ?? FileManager.default.temporaryDirectory
let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.boringnotch.unknown"
let appVersion = "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))"

let temporaryDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    ?? FileManager.default.temporaryDirectory
let spacing: CGFloat = 16

struct BluetoothDeviceIconMapping: Codable, Defaults.Serializable {
    let UUID: UUID
    let deviceName: String
    var sfSymbolName: String

    init(UUID: Foundation.UUID = Foundation.UUID(), deviceName: String, sfSymbolName: String) {
        self.UUID = UUID
        self.deviceName = deviceName
        self.sfSymbolName = sfSymbolName
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let mediaControllerChanged = Notification.Name("mediaControllerChanged")
    static let selectedScreenChanged = Notification.Name("SelectedScreenChanged")
    static let notchHeightChanged = Notification.Name("NotchHeightChanged")
    static let showOnAllDisplaysChanged = Notification.Name("showOnAllDisplaysChanged")
    static let automaticallySwitchDisplayChanged = Notification.Name("automaticallySwitchDisplayChanged")
    static let expandedDragDetectionChanged = Notification.Name("expandedDragDetectionChanged")
    static let accessibilityAuthorizationChanged = Notification.Name("accessibilityAuthorizationChanged")
    static let sharingDidFinish = Notification.Name("com.boringNotch.sharingDidFinish")
    static let accentColorChanged = Notification.Name("AccentColorChanged")
}
