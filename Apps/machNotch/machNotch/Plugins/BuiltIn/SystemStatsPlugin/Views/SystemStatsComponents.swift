//
//  SystemStatsComponents.swift
//  machNotch
//
//  Reusable subviews and formatters for the SystemStats plugin.
//

import SwiftUI

// MARK: - Metric Ring

struct SystemMetricRing: View {
    let label: String
    let value: Double
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.14), lineWidth: max(size * 0.09, 2))
            Circle()
                .trim(from: 0, to: value)
                .stroke(color, style: StrokeStyle(lineWidth: max(size * 0.09, 2), lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(SystemStatsFormatter.percent(value))
                    .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                Text(label)
                    .font(.system(size: size * 0.16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(.white.opacity(0.9))
        .animation(.smooth(duration: 0.25), value: value)
    }
}

// MARK: - Sparkline

struct SystemStatsSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                guard values.count > 1 else { return }
                for index in values.indices {
                    let x = proxy.size.width * CGFloat(index) / CGFloat(values.count - 1)
                    let y = proxy.size.height * (1 - CGFloat(min(max(values[index], 0), 1)))
                    index == values.startIndex
                        ? path.move(to: CGPoint(x: x, y: y))
                        : path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .shadow(color: color.opacity(0.35), radius: 4)
        }
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Formatter

enum SystemStatsFormatter {
    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    static func gigabytes(_ bytes: Double) -> String {
        String(format: "%.1f GB", bytes / 1_073_741_824)
    }

    static func compactRate(_ bytesPerSecond: Double) -> String {
        let kb = bytesPerSecond / 1_024
        return kb >= 100 ? "\(Int(kb / 1_024))M" : "\(Int(kb))K"
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        let kb = bytesPerSecond / 1_024
        if kb >= 1_024 {
            return String(format: "%.1f MB/s", kb / 1_024)
        }
        return "\(Int(kb.rounded())) KB/s"
    }
}
