//
//  BriefPlugin.swift
//  machNotch
//
//  Daily text brief — deterministic per-slot quote shown in the closed notch.
//

import MachBriefKit
import SwiftUI

@MainActor
@Observable
final class BriefPlugin: NotchPlugin, PositionedPlugin {

    let id = PluginID.brief

    let metadata = PluginMetadata(
        name: "Brief",
        description: "Shows a deterministic daily text brief.",
        icon: "text.append",
        category: .productivity
    )

    var isEnabled: Bool = true
    private(set) var state: PluginState = .inactive
    var closedNotchPosition: ClosedNotchPosition { .right }

    private var cachedEntry: BriefEntry?
    private let scheduler = DailyScheduler()
    private let source = QuoteSource()

    // MARK: - Lifecycle

    func activate(context: PluginContext) async throws {
        _ = context
        state = .activating
        let now = Date()
        let slot = scheduler.slot(for: now)
        cachedEntry = await source.entry(for: slot, date: now)
        state = .active
    }

    func deactivate() async {
        cachedEntry = nil
        state = .inactive
    }

    // MARK: - Display

    var displayRequest: DisplayRequest? {
        guard isEnabled, state.isActive, cachedEntry != nil else { return nil }
        return DisplayRequest(priority: .background, category: DisplayRequest.utility)
    }

    // MARK: - UI Slots

    @ViewBuilder
    func closedNotchContent() -> some View {
        if let entry = cachedEntry {
            HStack(spacing: 6) {
                Image(systemName: "text.append")
                    .font(.caption)
                Text(entry.title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    func expandedPanelContent() -> some View {
        if let entry = cachedEntry {
            VStack(alignment: .leading, spacing: 8) {
                Text("Daily Brief")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(entry.title)
                    .font(.headline)
                if let subtitle = entry.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
        }
    }
}
