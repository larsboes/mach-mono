//
//  BriefPlugin.swift
//  machNotch
//

import MachBriefKit
import SwiftUI
import Combine

extension Notification.Name {
    static let briefSettingsDidChange = Notification.Name("briefSettingsDidChange")
}

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
    private(set) var needsLevelOnboarding: Bool = true
    private(set) var currentLanguageID: String = BriefLanguage.defaultLanguage.id
    private let engine = BriefEngine()
    private let panelSources = ["word", "quote", "fact", "mantra"]
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var reloadTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func activate(context: PluginContext) async throws {
        _ = context
        state = .activating
        await reloadEntries()
        state = .active

        NotificationCenter.default.publisher(for: .briefSettingsDidChange)
            .sink { [weak self] _ in self?.scheduleReload() }
            .store(in: &cancellables)
    }

    func deactivate() async {
        cancellables.removeAll()
        reloadTask?.cancel()
        reloadTask = nil
        allEntries = [:]
        state = .inactive
    }

    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await self?.reloadEntries()
        }
    }

    private func reloadEntries() async {
        let now = Date()
        let settings = BriefSettingsCoding.load()
        needsLevelOnboarding = settings.vocabularyLevel == nil
        currentLanguageID = settings.wordLanguageID
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

    func setLanguage(_ id: String) {
        var settings = BriefSettingsCoding.load()
        settings.wordLanguageID = id
        BriefSettingsCoding.save(settings)
        NotificationCenter.default.post(name: .briefSettingsDidChange, object: nil)
    }

    func setVocabularyLevel(_ level: VocabularyLevel) {
        var settings = BriefSettingsCoding.load()
        settings.vocabularyLevel = level
        BriefSettingsCoding.save(settings)
        NotificationCenter.default.post(name: .briefSettingsDidChange, object: nil)
    }

    // MARK: - Display

    var displayRequest: DisplayRequest? {
        guard isEnabled, state.isActive else { return nil }
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
        if needsLevelOnboarding {
            VocabularyLevelPickerView { [weak self] level in
                self?.setVocabularyLevel(level)
            }
        } else {
            BriefExpandedView(
                entries: allEntries,
                sources: panelSources,
                languageID: currentLanguageID,
                onLanguageChange: { [weak self] id in self?.setLanguage(id) }
            )
        }
    }
}
