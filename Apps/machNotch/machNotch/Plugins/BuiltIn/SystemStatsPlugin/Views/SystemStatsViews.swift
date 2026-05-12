//
//  SystemStatsViews.swift
//  machNotch
//

import SwiftUI

struct SystemStatsConfiguration {
    let showCPU: Bool
    let showRAM: Bool
    let showDisk: Bool
    let showNetwork: Bool
}

struct SystemStatsClosedView: View {
    let stats: SystemStats
    let configuration: SystemStatsConfiguration

    var body: some View {
        HStack(spacing: 7) {
            if configuration.showCPU {
                SystemMetricRing(label: "CPU", value: stats.cpuUsage, color: .cyan, size: 28)
            }
            if configuration.showRAM {
                SystemMetricRing(label: "MEM", value: stats.ramUsage, color: .purple, size: 28)
            }
            if configuration.showDisk {
                SystemMetricRing(label: "DSK", value: stats.diskUsage, color: .orange, size: 28)
            }
            if configuration.showNetwork {
                networkBadge
            }
        }
        .padding(.horizontal, 8)
    }

    private var networkBadge: some View {
        VStack(spacing: 1) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 10, weight: .semibold))
            Text(SystemStatsFormatter.compactRate(stats.networkDownBytesPerSecond))
                .font(.system(size: 8, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.82))
    }
}

struct SystemStatsExpandedView: View {
    let stats: SystemStats
    let history: [SystemStats]
    let configuration: SystemStatsConfiguration

    @State private var hoveredCard: String?

    var body: some View {
        VStack(spacing: 10) {
            Label("System Stats", systemImage: "gauge.with.dots.needle.50percent")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            LazyVGrid(columns: metricColumns, spacing: 8) {
                if configuration.showCPU {
                    metricCard(
                        title: "CPU",
                        value: stats.cpuUsage,
                        history: history.map(\.cpuUsage),
                        color: .cyan,
                        hoverDetail: "User \(SystemStatsFormatter.percent(stats.cpuUserPercent))  ·  Sys \(SystemStatsFormatter.percent(stats.cpuSystemPercent))  ·  Idle \(SystemStatsFormatter.percent(max(0, 1 - stats.cpuUsage)))"
                    )
                }
                if configuration.showRAM {
                    metricCard(
                        title: "Memory",
                        value: stats.ramUsage,
                        history: history.map(\.ramUsage),
                        color: .purple,
                        hoverDetail: "\(SystemStatsFormatter.gigabytes(stats.ramUsedBytes)) used  of  \(SystemStatsFormatter.gigabytes(stats.ramTotalBytes))"
                    )
                }
                if configuration.showDisk {
                    metricCard(
                        title: "Disk",
                        value: stats.diskUsage,
                        history: history.map(\.diskUsage),
                        color: .orange,
                        hoverDetail: "\(SystemStatsFormatter.gigabytes(stats.diskUsedBytes)) used  ·  \(SystemStatsFormatter.gigabytes(stats.diskTotalBytes - stats.diskUsedBytes)) free"
                    )
                }
                if configuration.showNetwork {
                    networkCard
                }
            }
            .frame(maxWidth: 560)
        }
        .padding(.horizontal, 18)
        .padding(.top, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 180), spacing: 8),
            GridItem(.flexible(minimum: 180), spacing: 8)
        ]
    }

    private func metricCard(title: String, value: Double, history: [Double], color: Color, hoverDetail: String) -> some View {
        let isHovered = hoveredCard == title
        return HStack(spacing: 12) {
            SystemMetricRing(label: title.uppercased(), value: value, color: color, size: 38)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(SystemStatsFormatter.percent(value))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }

                ZStack(alignment: .leading) {
                    SystemStatsSparkline(values: history, color: color)
                        .opacity(isHovered ? 0 : 1)
                    Text(hoverDetail)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .opacity(isHovered ? 1 : 0)
                }
                .frame(height: 24)
                .animation(.easeInOut(duration: 0.16), value: isHovered)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 70)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
        .onHover { hovering in hoveredCard = hovering ? title : nil }
    }

    private var networkCard: some View {
        let isHovered = hoveredCard == "Network"
        let peakDown = history.map(\.networkDownBytesPerSecond).max() ?? 0
        let peakUp = history.map(\.networkUpBytesPerSecond).max() ?? 0
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.06))
                Image(systemName: "network")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.green)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Network")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(SystemStatsFormatter.compactRate(stats.networkDownBytesPerSecond))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }

                ZStack(alignment: .leading) {
                    SystemStatsSparkline(
                        values: normalizedNetworkHistory(\.networkDownBytesPerSecond),
                        color: .green
                    )
                    .opacity(isHovered ? 0 : 1)

                    HStack(spacing: 8) {
                        Text("Peak ↓ \(SystemStatsFormatter.rate(peakDown))")
                        Text("Peak ↑ \(SystemStatsFormatter.rate(peakUp))")
                    }
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .opacity(isHovered ? 1 : 0)
                }
                .frame(height: 20)
                .animation(.easeInOut(duration: 0.16), value: isHovered)

                HStack(spacing: 10) {
                    networkPill("Down", "arrow.down", stats.networkDownBytesPerSecond, .green)
                    networkPill("Up", "arrow.up", stats.networkUpBytesPerSecond, .blue)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 70)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
        .onHover { hovering in hoveredCard = hovering ? "Network" : nil }
    }

    private func networkPill(_ title: String, _ icon: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .foregroundStyle(.secondary)
            Text(SystemStatsFormatter.compactRate(value))
                .foregroundStyle(.white.opacity(0.85))
        }
        .font(.system(size: 9, weight: .medium, design: .rounded))
    }

    private func normalizedNetworkHistory(_ keyPath: KeyPath<SystemStats, Double>) -> [Double] {
        let values = history.map { $0[keyPath: keyPath] }
        guard let maxValue = values.max(), maxValue > 0 else { return values.map { _ in 0 } }
        return values.map { $0 / maxValue }
    }
}

struct SystemStatsSettingsView: View {
    let plugin: SystemStatsPlugin

    var body: some View {
        Form {
            Section("Visible Metrics") {
                Toggle("CPU", isOn: binding(\.showCPU))
                Toggle("Memory", isOn: binding(\.showRAM))
                Toggle("Disk", isOn: binding(\.showDisk))
                Toggle("Network", isOn: binding(\.showNetwork))
            }

            Section("Refresh") {
                Slider(
                    value: Binding(
                        get: { plugin.refreshInterval },
                        set: { plugin.refreshInterval = $0 }
                    ),
                    in: 1...5,
                    step: 1
                ) {
                    Text("Refresh Interval")
                }
                Text("\(Int(plugin.refreshInterval))s")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 360)
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<SystemStatsPlugin, Bool>) -> Binding<Bool> {
        Binding(
            get: { plugin[keyPath: keyPath] },
            set: { plugin[keyPath: keyPath] = $0 }
        )
    }
}

