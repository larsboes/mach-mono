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
    private let notificationCenter = UNUserNotificationCenter.current()
    private let calendar = Calendar.current

    init(store: any BriefStore) {
        self.store = store
        self.settings = BriefSettingsCoding.load()
    }

    func refresh(date: Date = Date()) async {
        currentSlot = engine.currentSlot(for: date)
        currentEntry = await engine.ensureEntry(for: date, settings: settings, store: store, sinks: obsidianSinks())
        await syncNotificationSchedule()
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

        guard isEnabled else {
            await clearPendingNotifications()
            statusMessage = "Notifications disabled"
            return
        }

        let granted = (try? await notificationCenter.requestAuthorization(options: [.alert, .sound])) ?? false
        if !granted {
            settings.notificationsEnabled = false
            persistSettings()
            statusMessage = "Notifications not allowed"
            await clearPendingNotifications()
            return
        }

        await syncNotificationSchedule()
        statusMessage = "Notifications enabled"
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

    private func syncNotificationSchedule() async {
        guard settings.notificationsEnabled else { return }
        let authorized = await notificationAuthorizationStatus() == .authorized
        if !authorized {
            settings.notificationsEnabled = false
            persistSettings()
            statusMessage = "Notifications disabled"
            await clearPendingNotifications()
            return
        }

        await clearPendingNotifications()

        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) else { return }
        let timeline = (
            await engine.timelineEntries(for: Date(), settings: settings)
        ) + (
            await engine.timelineEntries(for: tomorrow, settings: settings)
        )

        let upcoming = timeline
            .filter { $0.date > Date() }
            .sorted { $0.date < $1.date }
            .prefix(4)

        let plan = BriefNotificationPlanner.plan(for: Array(upcoming))

        for item in plan {
            do {
                try await notificationCenter.add(NotificationSink.request(for: item))
            } catch {
                statusMessage = "Notification scheduling failed"
                return
            }
        }

        statusMessage = plan.isEmpty ? "No notifications available" : "Notifications scheduled"
    }

    private func clearPendingNotifications() async {
        let identifiers = await machBriefNotificationIdentifiers()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func machBriefNotificationIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            notificationCenter.getPendingNotificationRequests { requests in
                continuation.resume(
                    returning: requests
                        .map(\.identifier)
                        .filter { $0.hasPrefix(NotificationSink.identifierPrefix) }
                )
            }
        }
    }

    private func notificationAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private func persistSettings() {
        BriefSettingsCoding.save(settings)
    }

    private func obsidianSinks() -> [any BriefSink] {
        guard let path = settings.obsidianNotePath, !path.isEmpty else { return [] }
        return [ObsidianSink(noteURL: URL(fileURLWithPath: path))]
    }
}
