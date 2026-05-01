import IOBluetooth
import CoreBluetooth
import SwiftUI
import Defaults
@Observable
@MainActor
final class BluetoothManager: NSObject, BackgroundServiceRestartable {

    var connectedDevices: [BluetoothDevice] = []
    var isScanning = false
    var bluetoothState: CBManagerState = .unknown
    var isInitialized = false

    private var centralManager: CBCentralManager?
    private var timer: Timer?
    private let settings: any NotchSettings

    init(settings: any NotchSettings) {
        self.settings = settings
        super.init()
    }
    
    func initializeBluetooth() {
        guard !isInitialized else { return }
        centralManager = CBCentralManager(delegate: self, queue: nil)
        startMonitoring()
        isInitialized = true
    }
    
    func startMonitoring() {
        updateConnectedDevices()
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateConnectedDevices() }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateConnectedDevices() {
        guard let devices = IOBluetoothDevice.pairedDevices() else { return }
        
        var newDevices: [BluetoothDevice] = []
        
        for device in devices {
            guard let device = device as? IOBluetoothDevice,
                  device.isConnected(),
                  let name = device.name else { continue }
            
            // Check if device is ignored
            if isDeviceIgnored(name) { continue }
            
            // Get battery level if available
            var batteryLevel: Int?
            
            // Try different methods to get battery level
            // Method 1: Apple's private API for battery level (often works for Apple devices)
            if let level = getBatteryLevel(for: device) {
                batteryLevel = level
            }
            
            let icon = getIconForDevice(name: name, deviceClass: device.classOfDevice)
            
            // Get custom icon if set
            let customIcon = getCustomIcon(for: name)
            
            let btDevice = BluetoothDevice(
                id: device.addressString,
                name: name,
                batteryLevel: batteryLevel,
                icon: customIcon ?? icon ?? "antenna.radiowaves.left.and.right",
                isConnected: true
            )
            
            newDevices.append(btDevice)
        }
        
        self.connectedDevices = newDevices
    }
    
    private func getBatteryLevel(for device: IOBluetoothDevice) -> Int? {
        // This is a simplified attempt. Getting battery levels reliably on macOS 
        // often requires private APIs or complex IOKit handling which might be restricted.
        // For now, we'll return nil unless we implement a more robust method later
        // or use the XPC helper if needed.
        return nil
    }
    
    private func isDeviceIgnored(_ name: String) -> Bool {
        // Implement ignore logic based on Defaults if needed
        return false
    }
    
    private func getCustomIcon(for deviceName: String) -> String? {
        let mappings = settings.bluetoothDeviceIconMappings
        return mappings.first(where: { $0.deviceName == deviceName })?.sfSymbolName
    }
    
    private func getIconForDevice(name: String, deviceClass: UInt32) -> String? {
        let name = name.lowercased()
        
        // --- Audio ---
        if name.contains("airpods max") { return "airpodsmax" }
        if name.contains("airpods pro") { return "airpodspro" }
        if name.contains("airpods") { return "airpods" }
        if name.contains("beats") { return "beats.headphones" }
        if name.contains("headphone") || name.contains("headset") { return "headphones" }
        if name.contains("speaker") { return "hifispeaker.fill" }
        
        // --- Input ---
        if name.contains("keyboard") { return "keyboard.fill" }
        if name.contains("mouse") && name.contains("magic") { return "magicmouse.fill" } else if name.contains("mouse") { return "computermouse.fill" }
        if name.contains("trackpad") { return "trackpad.fill" }
        
        // --- Gamepads ---
        if name.contains("gamepad") || name.contains("controller") || name.contains("joy-con") { return "gamecontroller.fill" }
        
        // --- Phones/Tablets ---
        if name.contains("iphone") { return "iphone" }
        if name.contains("ipad") { return "ipad" }
        
        return nil
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor in
            self.bluetoothState = state
            switch state {
            case .poweredOn:
                print("Bluetooth usable (permission granted)")
            case .unauthorized:
                print("Bluetooth permission denied")
            case .poweredOff:
                print("Bluetooth off")
            default:
                break
            }
        }
    }
}

struct BluetoothDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let batteryLevel: Int?
    let icon: String
    let isConnected: Bool
}
