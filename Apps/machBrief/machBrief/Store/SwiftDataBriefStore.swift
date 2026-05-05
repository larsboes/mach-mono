import Foundation
import SwiftData
import MachBriefKit

@MainActor
final class SwiftDataBriefStore: BriefStore {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    func save(_ entry: BriefEntry) async {
        if let existing = fetchStored(id: entry.id) {
            existing.update(from: entry)
            try? context.save()
            return
        }
        context.insert(StoredBriefEntry(from: entry))
        try? context.save()
    }

    func entry(for date: Date, slot: DailySlot) async -> BriefEntry? {
        let descriptor = FetchDescriptor<StoredBriefEntry>(sortBy: [SortDescriptor(\.revealedAt, order: .reverse)])
        let stored = (try? context.fetch(descriptor)) ?? []
        return stored.compactMap { $0.briefEntry() }.first { entry in
            entry.slot == slot && calendar.isDate(entry.revealedAt, inSameDayAs: date)
        }
    }

    func entries() async -> [BriefEntry] {
        let descriptor = FetchDescriptor<StoredBriefEntry>(sortBy: [SortDescriptor(\.revealedAt, order: .reverse)])
        let stored = (try? context.fetch(descriptor)) ?? []
        return stored.compactMap { $0.briefEntry() }
    }

    func entries(matching query: BriefArchiveQuery) async -> [BriefEntry] {
        await entries().filtered(by: query)
    }

    func updateFavorite(entryID: UUID, isFavorited: Bool) async {
        guard let stored = fetchStored(id: entryID) else { return }
        stored.isFavorited = isFavorited
        try? context.save()
    }

    func saveMoodResponse(entryID: UUID, rating: MoodRating, note: String?) async {
        guard var entry = fetchStored(id: entryID)?.briefEntry() else { return }
        entry.metadata["moodRating"] = rating.rawValue
        if let note, !note.isEmpty {
            entry.metadata["moodNote"] = note
        } else {
            entry.metadata.removeValue(forKey: "moodNote")
        }
        await save(entry)
    }

    private func fetchStored(id: UUID) -> StoredBriefEntry? {
        let descriptor = FetchDescriptor<StoredBriefEntry>()
        return (try? context.fetch(descriptor))?.first { $0.id == id }
    }
}
