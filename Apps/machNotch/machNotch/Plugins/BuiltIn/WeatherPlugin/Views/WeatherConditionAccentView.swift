import SwiftUI

struct WeatherConditionAccentView: View {
    let weather: WeatherData
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    private var style: WeatherConditionAccentStyle {
        WeatherConditionAccentStyle(weather: weather)
    }

    var body: some View {
        ZStack {
            switch style {
            case .sunny:
                sunnyAccent
            case .rainy:
                rainAccent
            case .windy:
                windAccent
            case .snowy:
                snowAccent
            case .cloudy:
                cloudAccent
            case .none:
                EmptyView()
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: style.duration).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
        .onDisappear {
            animate = false
        }
    }

    private var sunnyAccent: some View {
        Circle()
            .stroke(.yellow.opacity(animate ? 0.22 : 0.08), lineWidth: 1)
            .scaleEffect(animate ? 1.18 : 0.92)
            .blur(radius: 0.3)
    }

    private var rainAccent: some View {
        ForEach(0..<3, id: \.self) { index in
            Image(systemName: "drop.fill")
                .font(.system(size: size * 0.12, weight: .light))
                .foregroundStyle(.cyan.opacity(0.36))
                .offset(
                    x: CGFloat(index - 1) * size * 0.17,
                    y: animate ? size * 0.18 : -size * 0.08
                )
                .opacity(animate ? 0.16 : 0.42)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.8 + Double(index) * 0.18)
                        .repeatForever(autoreverses: false),
                    value: animate
                )
        }
    }

    private var windAccent: some View {
        VStack(spacing: size * 0.08) {
            windLine(width: size * 0.7, offset: animate ? size * 0.08 : -size * 0.08)
            windLine(width: size * 0.52, offset: animate ? -size * 0.06 : size * 0.06)
        }
        .foregroundStyle(.white.opacity(0.3))
    }

    private func windLine(width: CGFloat, offset: CGFloat) -> some View {
        Capsule()
            .fill(.white.opacity(0.26))
            .frame(width: width, height: 1)
            .offset(x: offset)
    }

    private var snowAccent: some View {
        ForEach(0..<2, id: \.self) { index in
            Image(systemName: "snowflake")
                .font(.system(size: size * 0.16, weight: .light))
                .foregroundStyle(.white.opacity(0.34))
                .offset(
                    x: CGFloat(index == 0 ? -1 : 1) * size * 0.18,
                    y: animate ? size * 0.1 : -size * 0.1
                )
                .rotationEffect(.degrees(animate ? 10 : -10))
        }
    }

    private var cloudAccent: some View {
        Image(systemName: "cloud.fill")
            .font(.system(size: size * 0.5, weight: .light))
            .foregroundStyle(.white.opacity(animate ? 0.12 : 0.06))
            .offset(x: animate ? size * 0.05 : -size * 0.03, y: size * 0.07)
    }
}

private enum WeatherConditionAccentStyle {
    case sunny
    case rainy
    case windy
    case snowy
    case cloudy
    case none

    init(weather: WeatherData) {
        let text = "\(weather.condition) \(weather.symbolName)".lowercased()
        if text.contains("wind") {
            self = .windy
        } else if text.contains("rain") || text.contains("drizzle") || text.contains("shower") {
            self = .rainy
        } else if text.contains("snow") || text.contains("sleet") {
            self = .snowy
        } else if text.contains("sun") || text.contains("clear") {
            self = .sunny
        } else if text.contains("cloud") || text.contains("fog") || text.contains("mist") || text.contains("smoke") {
            self = .cloudy
        } else {
            self = .none
        }
    }

    var duration: Double {
        switch self {
        case .sunny: return 3.8
        case .rainy: return 1.9
        case .windy: return 2.6
        case .snowy: return 3.2
        case .cloudy: return 4.4
        case .none: return 1
        }
    }
}
