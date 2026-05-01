import Foundation
import Cocoa
@preconcurrency import AsyncXPCConnection

@MainActor
final class XPCHelperClient: NSObject {
    static let shared = XPCHelperClient()
    
    private let serviceName = "theboringteam.boringnotch.BoringNotchXPCHelper"
    
    private var remoteService: RemoteXPCService<BoringNotchXPCHelperProtocol>?
    private var connection: NSXPCConnection?
    private var lastKnownAuthorization: Bool?
    private var monitoringTask: Task<Void, Never>?
    
    // Backoff state
    private var consecutiveFailures = 0
    private var nextAllowedAttempt: Date = .distantPast
    private let backoffDelays: [TimeInterval] = [1, 2, 4, 8, 15, 30]
    
    deinit {
        // connection?.invalidate() // Cannot invalidate in deinit if isolated
        // stopMonitoringAccessibilityAuthorization() // Cannot call isolated method in deinit
        
        // Invalidate manually or rely on system cleanup
    }
    
    // MARK: - Connection Management
    
    private func ensureRemoteService() -> RemoteXPCService<BoringNotchXPCHelperProtocol>? {
        if let existing = remoteService {
            return existing
        }
        
        // Check backoff
        guard Date() >= nextAllowedAttempt else {
            return nil
        }
        
        let conn = NSXPCConnection(serviceName: serviceName)
        
        conn.interruptionHandler = { [weak self] in
            Task { @MainActor in
                self?.handleConnectionFailure()
            }
        }
        
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.handleConnectionFailure()
            }
        }
        
        conn.resume()
        
        let service = RemoteXPCService<BoringNotchXPCHelperProtocol>(
            connection: conn,
            remoteInterface: BoringNotchXPCHelperProtocol.self
        )
        
        connection = conn
        remoteService = service
        
        // Success (potentially) - we'll reset failures when a command actually succeeds
        return service
    }
    
    private func handleConnectionFailure() {
        connection = nil
        remoteService = nil
        
        consecutiveFailures += 1
        let delay = backoffDelays[min(consecutiveFailures - 1, backoffDelays.count - 1)]
        nextAllowedAttempt = Date().addingTimeInterval(delay)
        
        print("XPC Connection failed. Consecutive failures: \(consecutiveFailures). Backing off for \(delay)s.")
    }
    
    private func resetBackoff() {
        if consecutiveFailures > 0 {
            consecutiveFailures = 0
            nextAllowedAttempt = .distantPast
            print("XPC Connection stable. Resetting backoff.")
        }
    }
    
    private func getRemoteService() -> RemoteXPCService<BoringNotchXPCHelperProtocol>? {
        remoteService
    }
    
    private func notifyAuthorizationChange(_ granted: Bool) {
        guard lastKnownAuthorization != granted else { return }
        lastKnownAuthorization = granted
        NotificationCenter.default.post(
            name: .accessibilityAuthorizationChanged,
            object: nil,
            userInfo: ["granted": granted]
        )
    }

    // MARK: - Monitoring
    func startMonitoringAccessibilityAuthorization(every interval: TimeInterval = 30.0) {
        // Ensure only one monitor exists
        stopMonitoringAccessibilityAuthorization()
        monitoringTask = Task.detached { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                _ = await self.isAccessibilityAuthorized()
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch { break }
            }
        }
    }

    func stopMonitoringAccessibilityAuthorization() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    // Expose whether the client is actively monitoring (useful for tests/debug)
    var isMonitoring: Bool {
        return monitoringTask != nil
    }
    
    // MARK: - Accessibility
    
    func requestAccessibilityAuthorization() {
        guard let service = ensureRemoteService() else { return }
        Task {
            try? await service.withService { service in
                service.requestAccessibilityAuthorization()
            }
        }
    }
    
    func isAccessibilityAuthorized() async -> Bool {
        guard let service = ensureRemoteService() else { return lastKnownAuthorization ?? false }
        do {
            let result: Bool = try await service.withContinuation { service, continuation in
                service.isAccessibilityAuthorized { authorized in
                    continuation.resume(returning: authorized)
                }
            }
            resetBackoff()
            notifyAuthorizationChange(result)
            return result
        } catch {
            handleConnectionFailure()
            return false
        }
    }
    
    func ensureAccessibilityAuthorization(promptIfNeeded: Bool) async -> Bool {
        guard let service = ensureRemoteService() else { return lastKnownAuthorization ?? false }
        do {
            let result: Bool = try await service.withContinuation { service, continuation in
                service.ensureAccessibilityAuthorization(promptIfNeeded) { authorized in
                    continuation.resume(returning: authorized)
                }
            }
            resetBackoff()
            notifyAuthorizationChange(result)
            return result
        } catch {
            handleConnectionFailure()
            return false
        }
    }
    
    // MARK: - Keyboard Brightness
    
    func isKeyboardBrightnessAvailable() async -> Bool {
        guard let service = ensureRemoteService() else { return false }
        do {
            let result = try await service.withContinuation { service, continuation in
                service.isKeyboardBrightnessAvailable { available in
                    continuation.resume(returning: available)
                }
            }
            resetBackoff()
            return result
        } catch {
            handleConnectionFailure()
            return false
        }
    }

    func currentKeyboardBrightness() async -> Float? {
        guard let service = ensureRemoteService() else { return nil }
        do {
            let result: NSNumber? = try await service.withContinuation { service, continuation in
                service.currentKeyboardBrightness { value in
                    continuation.resume(returning: value)
                }
            }
            resetBackoff()
            return result?.floatValue
        } catch {
            handleConnectionFailure()
            return nil
        }
    }

    func setKeyboardBrightness(_ value: Float) async -> Bool {
        guard let service = ensureRemoteService() else { return false }
        do {
            let result = try await service.withContinuation { service, continuation in
                service.setKeyboardBrightness(value) { success in
                    continuation.resume(returning: success)
                }
            }
            resetBackoff()
            return result
        } catch {
            handleConnectionFailure()
            return false
        }
    }
    
    // MARK: - Screen Brightness
    
    func isScreenBrightnessAvailable() async -> Bool {
        guard let service = ensureRemoteService() else { return false }
        do {
            let result = try await service.withContinuation { service, continuation in
                service.isScreenBrightnessAvailable { available in
                    continuation.resume(returning: available)
                }
            }
            resetBackoff()
            return result
        } catch {
            handleConnectionFailure()
            return false
        }
    }

    func currentScreenBrightness() async -> Float? {
        guard let service = ensureRemoteService() else { return nil }
        do {
            let result: NSNumber? = try await service.withContinuation { service, continuation in
                service.currentScreenBrightness { value in
                    continuation.resume(returning: value)
                }
            }
            resetBackoff()
            return result?.floatValue
        } catch {
            handleConnectionFailure()
            return nil
        }
    }

    func setScreenBrightness(_ value: Float) async -> Bool {
        guard let service = ensureRemoteService() else { return false }
        do {
            let result = try await service.withContinuation { service, continuation in
                service.setScreenBrightness(value) { success in
                    continuation.resume(returning: success)
                }
            }
            resetBackoff()
            return result
        } catch {
            handleConnectionFailure()
            return false
        }
    }
    
    // MARK: - Bluetooth Device Info
    func getBluetoothDeviceMinorClass(with deviceName: String) async -> String? {
        guard let service = ensureRemoteService() else { return nil }
        do {
            let result = try await service.withContinuation { service, continuation in
                service.getBluetoothDeviceMinorClass(with: deviceName) { minorClass in
                    continuation.resume(returning: minorClass)
                }
            }
            resetBackoff()
            return result
        } catch {
            handleConnectionFailure()
            return nil
        }
    }
}
