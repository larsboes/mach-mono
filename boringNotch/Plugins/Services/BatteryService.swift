import Foundation
import SwiftUI
import IOKit.ps

@MainActor
@Observable
class BatteryService: BatteryServiceProtocol, BackgroundServiceRestartable {
    // MARK: - Properties
    
    var levelBattery: Float = 0.0
    var isPluggedIn: Bool = false
    var isCharging: Bool = false
    var isInLowPowerMode: Bool = false
    var timeToFullCharge: Int = 0
    var maxCapacity: Float = 0.0
    var statusText: String = ""
    
    // Conformance to BatteryServiceProtocol (computed properties for protocol match)
    var level: Double { Double(levelBattery) }
    var timeRemaining: TimeInterval? { timeToFullCharge > 0 ? TimeInterval(timeToFullCharge * 60) : nil }
    
    // Internal state
    private var isInitial: Bool = true
    private let eventBus: PluginEventBus
    private let settings: any BatterySettings

    // Wrapper to handle non-Sendable CFRunLoopSource safely
    private final class SourceContainer: @unchecked Sendable {
        var source: CFRunLoopSource?
    }
    
    nonisolated private let sourceContainer = SourceContainer()
    
    // Error types
    enum BatteryError: Error {
        case powerSourceUnavailable
        case batteryInfoUnavailable(String)
        case batteryParameterMissing(String)
    }
    
    // MARK: - Initialization
    
    init(eventBus: PluginEventBus, settings: any BatterySettings) {
        self.eventBus = eventBus
        self.settings = settings
        // Initial update
        updateBatteryInfo()
        
        // Start monitoring
        startMonitoring()
        setupLowPowerModeObserver()
        
        // Mark initial check as done after a short delay
        Task {
            try? await Task.sleep(for: .seconds(1))
            self.isInitial = false
        }
    }
    
    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        guard let powerSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                service.updateBatteryInfo()
            }
        }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue() else {
            return
        }
        
        sourceContainer.source = powerSource
        CFRunLoopAddSource(CFRunLoopGetMain(), powerSource, .defaultMode)
    }
    
    nonisolated func stopMonitoring() {
        if let powerSource = sourceContainer.source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .defaultMode)
            sourceContainer.source = nil
        }
    }
    
    private func setupLowPowerModeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryInfo()
            }
        }
    }
    
    // MARK: - Updates
    
    func updateBatteryInfo() {
        let info = getBatteryInfo()
        
        // Check for changes to notify
        let levelChanged = self.levelBattery != info.currentCapacity
        let pluggedInChanged = self.isPluggedIn != info.isPluggedIn
        let chargingChanged = self.isCharging != info.isCharging
        let lowPowerChanged = self.isInLowPowerMode != info.isInLowPowerMode
        
        // Update state
        self.levelBattery = info.currentCapacity
        self.isPluggedIn = info.isPluggedIn
        self.isCharging = info.isCharging
        self.isInLowPowerMode = info.isInLowPowerMode
        self.timeToFullCharge = info.timeToFullCharge
        self.maxCapacity = info.maxCapacity
        
        // Update status text
        if info.isCharging {
            self.statusText = "Charging battery"
        } else if info.isPluggedIn {
            self.statusText = info.currentCapacity < info.maxCapacity ? "Not charging" : "Full charge"
        } else {
            self.statusText = "Unplugged"
        }
        
        if info.isInLowPowerMode {
            self.statusText += " (Low Power)"
        }
        
        // Notifications
        if levelChanged || pluggedInChanged || chargingChanged || lowPowerChanged {
            notifyImportantChange(levelChanged: levelChanged)
        }
    }
    
    private func getBatteryInfo() -> BatteryInfo {
        do {
            guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
                throw BatteryError.powerSourceUnavailable
            }
            
            guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
                  !sources.isEmpty else {
                // No power source (desktop?), return default
                return BatteryInfo.defaultInfo
            }
            
            guard let source = sources.first else {
                return BatteryInfo.defaultInfo
            }
            
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                throw BatteryError.batteryInfoUnavailable("Could not get power source description")
            }
            
            let currentCapacity = description[kIOPSCurrentCapacityKey] as? Float ?? 0
            let maxCapacity = description[kIOPSMaxCapacityKey] as? Float ?? 0
            let isCharging = description["Is Charging"] as? Bool ?? false
            let powerSource = description[kIOPSPowerSourceStateKey] as? String
            let isPluggedIn = powerSource == kIOPSACPowerValue
            let timeToFull = description[kIOPSTimeToFullChargeKey] as? Int ?? 0
            
            return BatteryInfo(
                isPluggedIn: isPluggedIn,
                isCharging: isCharging,
                currentCapacity: currentCapacity,
                maxCapacity: maxCapacity,
                isInLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                timeToFullCharge: timeToFull
            )
            
        } catch {
            print("BatteryService Error: \(error)")
            return BatteryInfo.defaultInfo
        }
    }
    
    private func notifyImportantChange(levelChanged: Bool) {
        Task {
            // Check for battery level notifications
            if levelChanged, let notificationType = checkBatteryLevel(level: Int(self.levelBattery), initial: self.isInitial) {
                var soundToPlay = "Disabled"
                if notificationType == "Low Battery" {
                    soundToPlay = settings.lowBatteryNotificationSound
                } else if notificationType == "High Battery" {
                    soundToPlay = settings.highBatteryNotificationSound
                }
                
                eventBus.emit(SneakPeekRequestedEvent(
                    sourcePluginId: PluginID.System.battery,
                    request: SneakPeekRequest(style: .expanding, type: .battery)
                ))
                
                if soundToPlay != "Disabled" {
                    NSSound(named: NSSound.Name(soundToPlay))?.play()
                }
                
            } else if settings.showPowerStatusNotifications && !isInitial {
                // Standard power status notification
                let soundToPlay = settings.powerStatusNotificationSound
                eventBus.emit(SneakPeekRequestedEvent(
                    sourcePluginId: PluginID.System.battery,
                    request: SneakPeekRequest(style: .expanding, type: .battery)
                ))
                
                if soundToPlay != "Disabled" {
                    NSSound(named: NSSound.Name(soundToPlay))?.play()
                }
            }
        }
    }
    
    private func checkBatteryLevel(level: Int, initial: Bool) -> String? {
        let lowThreshold = settings.lowBatteryNotificationLevel
        let highThreshold = settings.highBatteryNotificationLevel
        
        if !self.isCharging && (level == lowThreshold || (initial && level <= lowThreshold)) && lowThreshold > 0 {
            return "Low Battery"
        }
        if self.isCharging && (level == highThreshold || (initial && level >= highThreshold)) && highThreshold > 0 {
            return "High Battery"
        }
        return nil
    }
}

struct BatteryInfo {
    var isPluggedIn: Bool
    var isCharging: Bool
    var currentCapacity: Float
    var maxCapacity: Float
    var isInLowPowerMode: Bool
    var timeToFullCharge: Int
    
    static let defaultInfo = BatteryInfo(
        isPluggedIn: false,
        isCharging: false,
        currentCapacity: 0,
        maxCapacity: 0,
        isInLowPowerMode: false,
        timeToFullCharge: 0
    )
}
