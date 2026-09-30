//
//  AxonClosedView.swift
//  NotchAxonPlugin
//
//  Compact glanceable pill rendered in the closed notch surface.
//

import SwiftUI

public struct AxonClosedView: View {
    @Bindable var plugin: AxonPlugin

    public init(plugin: AxonPlugin) {
        self.plugin = plugin
    }

    public var body: some View {
        HStack(spacing: 6) {
            // Live Status Indicator / Icon
            if let commitment = plugin.upcomingCommitment, commitment.isImminent {
                Circle()
                    .fill(Color.emerald400)
                    .frame(width: 6, height: 6)
            } else {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(plugin.isAxonOnline ? Color.emerald400 : Color.gray.opacity(0.8))
            }

            // Text pill
            if let commitment = plugin.upcomingCommitment {
                Text(commitment.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 110)

                Text(commitment.relativeTimeText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(commitment.isImminent ? Color.emerald400 : Color.gray)
            } else {
                Text("Axon")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 4)
        .foregroundStyle(.white)
    }
}

private extension Color {
    static let emerald400 = Color(red: 52/255, green: 211/255, blue: 153/255)
}
