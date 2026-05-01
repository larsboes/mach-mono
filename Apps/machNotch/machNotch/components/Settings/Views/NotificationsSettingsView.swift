import SwiftUI

struct NotificationsSettingsView: View {
    @Environment(\.pluginManager) var pluginManager
    @Environment(\.bindableSettings) var settings
    
    private var manager: (any NotificationServiceProtocol)? {
        pluginManager?.services.notifications
    }

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                HStack {
                    Text("Permission Status")
                    Spacer()
                    Text(authorizationLabel)
                        .foregroundStyle(.secondary)
                }
                
                if manager?.authorizationStatus != .authorized {
                    Button("Request permission") {
                        manager?.requestAuthorization()
                    }
                }
            } header: {
                Text("General")
            }
            
            Section {
                Toggle(isOn: $settings.showShelfNotifications) {
                    Text("Shelf Events")
                }
                Toggle(isOn: $settings.showSystemNotifications) {
                    Text("System Events")
                }
                Toggle(isOn: $settings.showInfoNotifications) {
                    Text("Info & Updates")
                }
            } header: {
                Text("Sources")
            }
            
            Section {
                Picker("Delivery Style", selection: $settings.notificationDeliveryStyle) {
                    ForEach(NotificationDeliveryStyle.allCases, id: \.self) { style in
                        Text(style.localizedName).tag(style)
                    }
                }
                
                Toggle(isOn: $settings.notificationSoundEnabled) {
                    Text("Play sound")
                }
                
                Toggle(isOn: $settings.respectDoNotDisturb) {
                    Text("Respect Do Not Disturb / Focus")
                }
                
                Stepper(value: $settings.notificationRetentionDays, in: 1...30) {
                    Text("Keep history for \(settings.notificationRetentionDays) days")
                }
            } header: {
                Text("History")
            }
        }
        .accentColor(.effectiveAccent(from: settings))
        .navigationTitle("Notifications")
        .onAppear {
            manager?.refreshAuthorizationStatus()
        }
    }

    private var authorizationLabel: String {
        switch manager?.authorizationStatus {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not determined"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        case nil:
            return "Unknown"
        @unknown default:
            return "Unknown"
        }
    }
}
