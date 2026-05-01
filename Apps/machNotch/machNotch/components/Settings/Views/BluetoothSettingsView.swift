import SwiftUI

struct BluetoothSettingsView: View {
    var bluetoothManager: any BluetoothStateServiceProtocol
    @State private var iconPickerPresented = false
    @State private var selectedDeviceForIcon: String?
    @Environment(\.bindableSettings) var settings
    
    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                if !bluetoothManager.isInitialized {
                    Button("Enable Bluetooth Integration") {
                        bluetoothManager.initializeBluetooth()
                    }
                } else {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(statusText)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("General")
            }
            
            Section {
                Toggle(isOn: $settings.enableBluetoothSneakPeek) {
                    Text("Show connection notifications")
                }
                
                Picker("Notification Style", selection: $settings.bluetoothSneakPeekStyle) {
                    Text("Standard").tag(SneakPeekStyle.standard)
                    Text("Minimal").tag(SneakPeekStyle.minimal)
                }
                .disabled(!settings.enableBluetoothSneakPeek)
            } header: {
                Text("Notifications")
            }
            
            if bluetoothManager.isInitialized {
                Section {
                    if bluetoothManager.connectedDevices.isEmpty {
                        Text("No connected devices found")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(bluetoothManager.connectedDevices) { device in
                            HStack {
                                Image(systemName: device.icon)
                                    .frame(width: 20)
                                Text(device.name)
                                Spacer()
                                Button("Change Icon") {
                                    selectedDeviceForIcon = device.name
                                    iconPickerPresented = true
                                }
                                .buttonStyle(.link)
                                .font(.caption)
                            }
                        }
                    }
                } header: {
                    Text("Connected Devices")
                }
            }
        }
        .accentColor(.effectiveAccent(from: settings))
        .navigationTitle("Bluetooth")
        .onAppear {
            Task { @MainActor in
                if bluetoothManager.isInitialized == false {
                    bluetoothManager.initializeBluetooth()
                }
            }
        }
        .sheet(isPresented: $iconPickerPresented) {
            IconPickerSheet(deviceName: selectedDeviceForIcon ?? "")
        }
    }
    
    private var statusText: String {
        switch bluetoothManager.bluetoothState {
        case .poweredOn: return "Active"
        case .poweredOff: return "Bluetooth Off"
        case .unauthorized: return "Unauthorized"
        case .unknown: return "Initializing..."
        case .unsupported: return "Unsupported"
        case .resetting: return "Resetting..."
        @unknown default: return "Unknown"
        }
    }
}

struct IconPickerSheet: View {
    let deviceName: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.bindableSettings) var settings
    @State private var searchText = ""
    
    let commonIcons = [
        "headphones", "airpods", "airpods.pro", "airpodsmax", 
        "beats.headphones", "hifispeaker.fill", "keyboard.fill", 
        "computermouse.fill", "magicmouse.fill", "trackpad.fill",
        "gamecontroller.fill", "iphone", "ipad", "applewatch"
    ]
    
    var body: some View {
        @Bindable var settings = settings
        VStack {
            Text("Select Icon for \(deviceName)")
                .font(.headline)
                .padding()
            
            TextField("Search SF Symbols", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 20) {
                    ForEach(commonIcons, id: \.self) { icon in
                        Button {
                            saveIcon(icon)
                        } label: {
                            Image(systemName: icon)
                                .font(.title)
                                .frame(width: 40, height: 40)
                                .padding(5)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
            }
            .padding()
        }
        .frame(width: 400, height: 500)
    }
    
    private func saveIcon(_ icon: String) {
        var mappings = settings.bluetoothDeviceIconMappings
        if let index = mappings.firstIndex(where: { $0.deviceName == deviceName }) {
            mappings[index].sfSymbolName = icon
        } else {
            mappings.append(BluetoothDeviceIconMapping(deviceName: deviceName, sfSymbolName: icon))
        }
        settings.bluetoothDeviceIconMappings = mappings
        dismiss()
    }
}
