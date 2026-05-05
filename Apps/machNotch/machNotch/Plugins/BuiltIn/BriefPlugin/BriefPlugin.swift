//
//  BriefPlugin.swift
//  machNotch
//
//  Daily text brief — deterministic per-slot entry shown in the closed notch.
//

import MachBriefKit
import SwiftUI

@MainActor
@Observable
final class BriefPlugin: NotchPlugin, PositionedPlugin {

    let id = PluginID.brief

    let metadata = PluginMetadata(
        name: "Brief",
        description: "Shows the current mach.brief word, fact, quote, mantra, or mood prompt.",
        icon: "text.book.closed",
        category: .productivity
    )

    var isEnabled: Bool = true
    private(set) var state: PluginState = .inactive
    var closedNotchPosition: ClosedNotchPosition { .right }

    private var cachedEntry: BriefEntry?
    private let engine = BriefEngine()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func activate(context: PluginContext) async throws {
        _ = context
        state = .activating
        await reloadEntry()
        state = .active
        
        NotificationCenter.default.publisher(for: NSNotification.Name("briefSettingsDidChange"))
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.reloadEntry()
                }
            }
            .store(in: &cancellables)
    }

    func deactivate() async {
        cancellables.removeAll()
        cachedEntry = nil
        state = .inactive
    }
    
    private func reloadEntry() async {
        let now = Date()
        let settings = BriefSettingsCoding.load()
        cachedEntry = await engine.entry(for: now, settings: settings)
    }

    // MARK: - Display

    var displayRequest: DisplayRequest? {
        guard isEnabled, state.isActive, cachedEntry != nil else { return nil }
        return DisplayRequest(priority: .background, category: DisplayRequest.utility)
    }

    // MARK: - UI Slots

    @ViewBuilder
    func settingsContent() -> some View {
        BriefSettingsView()
    }

    @ViewBuilder
    func closedNotchContent() -> some View {
        if let entry = cachedEntry {
            HStack(spacing: 6) {
                Image(systemName: BriefSourceRegistry.descriptor(for: entry.sourceID).systemImage)
                    .font(.caption)
                Text(entry.sourceID == "word" ? entry.title.lowercased() : entry.title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    func expandedPanelContent() -> some View {
        if let entry = cachedEntry {
            if entry.sourceID == "word" {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Word of the day", systemImage: "textformat.abc")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.45, green: 0.58, blue: 0.55))
                    Text(entry.title.lowercased())
                        .font(.system(size: 34, weight: .bold, design: .serif))
                    if let subtitle = entry.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    if let body = entry.body, !body.isEmpty {
                        Text(body)
                            .font(.callout)
                            .foregroundStyle(.primary)
                    }
                    if let example = entry.metadata["example"] {
                        Text(example)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(16)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(BriefSourceRegistry.descriptor(for: entry.sourceID).displayName)
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
}
