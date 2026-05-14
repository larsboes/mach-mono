import SwiftUI

struct BatteryView: View {

    var levelBattery: Float
    var isPluggedIn: Bool
    var isCharging: Bool
    var isInLowPowerMode: Bool
    var batteryWidth: CGFloat = 26
    var isForNotification: Bool
    var settings: NotchSettings

    var icon: String = "battery.0"

    var iconStatus: String {
        if isCharging {
            return "bolt"
        } else if isPluggedIn {
            return "plug"
        } else {
            return ""
        }
    }

    var batteryColor: Color {
        if isInLowPowerMode {
            return .yellow
        } else if levelBattery <= 20 && !isCharging && !isPluggedIn {
            return .red
        } else {
            return .green
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {

            Image(systemName: icon)
                .resizable()
                .fontWeight(.thin)
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: batteryWidth + 1)

            RoundedRectangle(cornerRadius: 2.5)
                .fill(batteryColor)
                .frame(
                    width: CGFloat(((CGFloat(CFloat(levelBattery)) / 100) * (batteryWidth - 6))),
                    height: (batteryWidth - 2.75) - 18
                )
                .padding(.leading, 2)

            if settings.showBatteryPercentage {
                Text("\(Int(levelBattery))")
                    .font(.system(size: batteryWidth * 0.32, weight: .heavy, design: .rounded))
                    .foregroundColor(batteryColor == .white ? .black : .white)
                    .shadow(color: batteryColor == .white ? .clear : .black.opacity(0.4), radius: 0.5, x: 0, y: 0)
                    .frame(width: batteryWidth - 3, alignment: .center)
            } else if !iconStatus.isEmpty && (isForNotification || settings.showPowerStatusIcons) {
                ZStack {
                    Image(iconStatus)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.white)
                        .frame(width: 17, height: 17)
                }
                .frame(width: batteryWidth, height: batteryWidth)
            }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
