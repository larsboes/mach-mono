//
//  BriefPlugin.swift
//  machNotch
//
//  Daily text brief — word, quote, fact, and mantra shown in a 4-panel hover view.
//

import MachBriefKit
import SwiftUI
import Combine

@MainActor
@Observable
final class BriefPlugin: NotchPlugin, PositionedPlugin {

    let id = PluginID.brief

    let metadata = PluginMetadata(
        name: "Brief",
        description: "Word, quote, fact, and mantra — all in one hover panel.",
        icon: "text.book.closed",
        category: .productivity
    )

    var isEnabled: Bool = true
    private(set) var state: PluginState = .inactive
    var closedNotchPosition: ClosedNotchPosition { .right }

    private(set) var allEntries: [String: BriefEntry] = [:]
    private let engine = BriefEngine()
    private let panelSources = ["word", "quote", "fact", "mantra"]
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func activate(context: PluginContext) async throws {
        _ = context
        state = .activating
        await reloadEntries()
        state = .active

        NotificationCenter.default.publisher(for: NSNotification.Name("briefSettingsDidChange"))
            .sink { [weak self] _ in
                Task { @MainActor in await self?.reloadEntries() }
            }
            .store(in: &cancellables)
    }

    func deactivate() async {
        cancellables.removeAll()
        allEntries = [:]
        state = .inactive
    }

    private func reloadEntries() async {
        let now = Date()
        let settings = BriefSettingsCoding.load()
        var fetched: [String: BriefEntry] = [:]
        await withTaskGroup(of: (String, BriefEntry).self) { group in
            for sourceID in panelSources {
                group.addTask {
                    let entry = await self.engine.entry(for: sourceID, date: now, settings: settings)
                    return (sourceID, entry)
                }
            }
            for await (sourceID, entry) in group {
                fetched[sourceID] = entry
            }
        }
        allEntries = fetched
    }

    // MARK: - Display

    var displayRequest: DisplayRequest? {
        guard isEnabled, state.isActive, !allEntries.isEmpty else { return nil }
        return DisplayRequest(priority: .background, category: DisplayRequest.utility)
    }

    // MARK: - UI Slots

    @ViewBuilder
    func settingsContent() -> some View {
        BriefSettingsView()
    }

    @ViewBuilder
    func closedNotchContent() -> some View {
        if let entry = allEntries["word"] {
            HStack(spacing: 6) {
                Image(systemName: "textformat.abc")
                    .font(.caption)
                Text(entry.title.lowercased())
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    func expandedPanelContent() -> some View {
        BriefExpandedView(entries: allEntries, sources: panelSources)
    }
}
