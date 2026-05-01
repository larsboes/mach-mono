//
//  XPCHelperServiceProtocol.swift
//  boringNotch
//
//  Protocol for XPC helper operations. Decouples consumers from the concrete
//  XPCHelperClient singleton, enabling dependency injection and testing.
//

import Foundation

/// Protocol abstracting XPC helper operations (accessibility, brightness, keyboard backlight).
/// Consumers depend on this protocol instead of `XPCHelperClient.shared` directly.
@MainActor
protocol XPCHelperServiceProtocol: AnyObject {
    // MARK: - Accessibility

    /// Request accessibility authorization via system prompt
    func requestAccessibilityAuthorization()

    /// Check if accessibility is authorized
    func isAccessibilityAuthorized() async -> Bool

    /// Ensure accessibility authorization, optionally prompting the user
    func ensureAccessibilityAuthorization(promptIfNeeded: Bool) async -> Bool

    // MARK: - Monitoring

    /// Start polling accessibility authorization status
    func startMonitoringAccessibilityAuthorization(every interval: TimeInterval)

    /// Stop polling accessibility authorization status
    func stopMonitoringAccessibilityAuthorization()

    /// Whether the client is currently monitoring
    var isMonitoring: Bool { get }

    // MARK: - Screen Brightness

    /// Check if screen brightness control is available
    func isScreenBrightnessAvailable() async -> Bool

    /// Get current screen brightness (0.0-1.0)
    func currentScreenBrightness() async -> Float?

    /// Set screen brightness (0.0-1.0)
    func setScreenBrightness(_ value: Float) async -> Bool

    // MARK: - Keyboard Backlight

    /// Check if keyboard backlight control is available
    func isKeyboardBrightnessAvailable() async -> Bool

    /// Get current keyboard brightness (0.0-1.0)
    func currentKeyboardBrightness() async -> Float?

    /// Set keyboard brightness (0.0-1.0)
    func setKeyboardBrightness(_ value: Float) async -> Bool

    // MARK: - Bluetooth

    /// Get Bluetooth device minor class
    func getBluetoothDeviceMinorClass(with deviceName: String) async -> String?
}

// MARK: - Default parameter value
extension XPCHelperServiceProtocol {
    func startMonitoringAccessibilityAuthorization() {
        startMonitoringAccessibilityAuthorization(every: 30.0)
    }
}

// MARK: - Conformance
extension XPCHelperClient: XPCHelperServiceProtocol {}
