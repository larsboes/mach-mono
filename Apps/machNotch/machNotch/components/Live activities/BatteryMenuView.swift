import SwiftUI

struct BatteryMenuView: View {

    var isPluggedIn: Bool
    var isCharging: Bool
    var levelBattery: Float
    var maxCapacity: Float
    var timeToFullCharge: Int
    var isInLowPowerMode: Bool
    var onDismiss: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {
                Text("Battery Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(Int(levelBattery))%")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Max Capacity: \(Int(maxCapacity))%")
                    .font(.subheadline)
                    .fontWeight(.regular)
                if isInLowPowerMode {
                    Label("Low Power Mode", systemImage: "bolt.circle")
                        .font(.subheadline)
                        .fontWeight(.regular)
                }
                if isCharging {
                    Label("Charging", systemImage: "bolt.fill")
                        .font(.subheadline)
                        .fontWeight(.regular)
                }
                if isPluggedIn {
                    Label("Plugged In", systemImage: "powerplug.fill")
                        .font(.subheadline)
                        .fontWeight(.regular)
                }
                if timeToFullCharge > 0 {
                    Label("Time to Full Charge: \(timeToFullCharge) min", systemImage: "clock")
                        .font(.subheadline)
                        .fontWeight(.regular)
                }
                if !isCharging && isPluggedIn && levelBattery >= 80 {
                    Label("Charging on Hold: Desktop Mode", systemImage: "desktopcomputer")
                        .font(.subheadline)
                        .fontWeight(.regular)
                }
            }
            .padding(.vertical, 8)

            Divider().background(Color.white)

            Button(action: openBatteryPreferences) {
                Label("Battery Settings", systemImage: "gearshape")
                    .fontWeight(.regular)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)
            .padding(.vertical, 8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .foregroundColor(.white)
    }

    private func openBatteryPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
            openURL(url)
            onDismiss()
        }
    }
}
