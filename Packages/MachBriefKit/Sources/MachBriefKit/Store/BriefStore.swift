import Foundation

public protocol BriefStore: Sendable {
    func save(_ entry: BriefEntry) async
    func entry(for date: Date, slot: DailySlot) async -> BriefEntry?
    func entries() async -> [BriefEntry]
    func entries(matching query: BriefArchiveQuery) async -> [BriefEntry]
    func updateFavorite(entryID: UUID, isFavorited: Bool) async
    func saveMoodResponse(entryID: UUID, rating: MoodRating, note: String?) async
}

public actor InMemoryBriefStore: BriefStore {
    private var values: [BriefEntry] = []
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func save(_ entry: BriefEntry) {
        if let index = values.firstIndex(where: { $0.id == entry.id }) {
            values[index] = entry
            return
        }
        values.insert(entry, at: 0)
    }

    public func entry(for date: Date, slot: DailySlot) -> BriefEntry? {
        values.first { entry in
            entry.slot == slot && calendar.isDate(entry.revealedAt, inSameDayAs: date)
        }
    }

    public func entries() -> [BriefEntry] {
        values
    }

    public func entries(matching query: BriefArchiveQuery) -> [BriefEntry] {
        values.filtered(by: query)
    }

    public func updateFavorite(entryID: UUID, isFavorited: Bool) {
        guard let index = values.firstIndex(where: { $0.id == entryID }) else { return }
        values[index].isFavorited = isFavorited
    }

    public func saveMoodResponse(entryID: UUID, rating: MoodRating, note: String?) {
        guard let index = values.firstIndex(where: { $0.id == entryID }) else { return }
        var entry = values[index]
        entry.metadata["moodRating"] = rating.rawValue
        if let note, !note.isEmpty {
            entry.metadata["moodNote"] = note
        } else {
            entry.metadata.removeValue(forKey: "moodNote")
        }
        values[index] = entry
    }
}

public struct BriefArchiveQuery: Sendable {
    public var sourceID: String?
    public var searchText: String
    public var favoritesOnly: Bool

    public init(sourceID: String? = nil, searchText: String = "", favoritesOnly: Bool = false) {
        self.sourceID = sourceID
        self.searchText = searchText
        self.favoritesOnly = favoritesOnly
    }
}

extension Array where Element == BriefEntry {
    public func filtered(by query: BriefArchiveQuery) -> [BriefEntry] {
        let normalizedSearch = query.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return filter { entry in
            if let sourceID = query.sourceID, entry.sourceID != sourceID {
                return false
            }
            if query.favoritesOnly && !entry.isFavorited {
                return false
            }
            guard !normalizedSearch.isEmpty else {
                return true
            }
            return entry.title.lowercased().contains(normalizedSearch)
                || (entry.subtitle?.lowercased().contains(normalizedSearch) ?? false)
                || (entry.body?.lowercased().contains(normalizedSearch) ?? false)
        }
    }
}
