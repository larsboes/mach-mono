import Foundation
import Observation
import MachBriefKit
import UserNotifications

@MainActor
@Observable
final class BriefTodayViewModel {
    var currentEntry: BriefEntry?
    var currentSlot: DailySlot = .morning
    var settings: BriefSettings
    var statusMessage: String?

    let sourceDescriptors = BriefSourceRegistry.descriptors
    private let engine = BriefEngine()
    private let store: any BriefStore

    init(store: any BriefStore) {
        self.store = store
        self.settings = BriefSettingsCoding.load()
    }

    func refresh(date: Date = Date()) async {
        currentSlot = engine.currentSlot(for: date)
        currentEntry = await engine.ensureEntry(for: date, settings: settings, store: store, sinks: obsidianSinks())
    }

    func toggleFavorite() async {
        guard var entry = currentEntry else { return }
        entry.isFavorited.toggle()
        await store.updateFavorite(entryID: entry.id, isFavorited: entry.isFavorited)
        currentEntry = entry
    }

    func saveMood(rating: MoodRating, note: String?) async {
        guard var entry = currentEntry else { return }
        entry.metadata[MoodMetadataKey.moodRating.rawValue] = rating.rawValue
        if let note, !note.isEmpty {
            entry.metadata[MoodMetadataKey.moodNote.rawValue] = note
        }
        await store.saveMoodResponse(entryID: entry.id, rating: rating, note: note)
        currentEntry = entry
    }

    func setSource(_ sourceID: String, enabled: Bool) {
        if enabled {
            settings.enabledSourceIDs.insert(sourceID)
        } else {
            settings.enabledSourceIDs.remove(sourceID)
        }
        persistSettings()
    }

    func setAssignedSource(_ sourceID: String, for slot: DailySlot) {
        settings.slotAssignments[slot] = sourceID
        settings.enabledSourceIDs.insert(sourceID)
        persistSettings()
    }

    func setWordLanguage(_ languageID: String) {
        settings.wordLanguageID = languageID
        settings.customWordListPath = nil
        persistSettings()
    }

    func setCustomWordListPath(_ path: String?) {
        settings.customWordListPath = path
        persistSettings()
    }

    func setNotificationsEnabled(_ isEnabled: Bool) async {
        settings.notificationsEnabled = isEnabled
        persistSettings()
        guard isEnabled else { return }
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        statusMessage = granted ? "Notifications enabled" : "Notifications not allowed"
    }

    func setObsidianNotePath(_ path: String?) {
        settings.obsidianNotePath = path
        persistSettings()
    }

    func testObsidianWrite() async {
        guard let path = settings.obsidianNotePath, !path.isEmpty else {
            statusMessage = "Choose an Obsidian note first"
            return
        }
        let entry: BriefEntry
        if let currentEntry {
            entry = currentEntry
        } else {
            entry = await engine.entry(for: Date(), settings: settings)
        }
        await ObsidianSink(noteURL: URL(fileURLWithPath: path)).receive(entry)
        statusMessage = "Test write sent"
    }

    private func persistSettings() {
        BriefSettingsCoding.save(settings)
    }

    private func obsidianSinks() -> [any BriefSink] {
        guard let path = settings.obsidianNotePath, !path.isEmpty else { return [] }
        return [ObsidianSink(noteURL: URL(fileURLWithPath: path))]
    }
}
