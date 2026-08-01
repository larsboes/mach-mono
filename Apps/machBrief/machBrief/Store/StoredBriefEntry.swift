import Foundation
import SwiftData
import MachBriefKit

@Model
final class StoredBriefEntry {
    var id: UUID
    var sourceID: String
    var slotRawValue: Int
    var title: String
    var subtitle: String?
    var body: String?
    var metadataJSON: String
    var isFavorited: Bool
    var revealedAt: Date

    init(from entry: BriefEntry) {
        self.id = entry.id
        self.sourceID = entry.sourceID
        self.slotRawValue = entry.slot.rawValue
        self.title = entry.title
        self.subtitle = entry.subtitle
        self.body = entry.body
        self.metadataJSON = Self.encodeMetadata(entry.metadata)
        self.isFavorited = entry.isFavorited
        self.revealedAt = entry.revealedAt
    }

    func briefEntry(calendar: Calendar = .current) -> BriefEntry? {
        let slot = DailySlot(rawValue: slotRawValue) ?? Self.slot(for: revealedAt, calendar: calendar)
        return BriefEntry(
            id: id,
            sourceID: sourceID,
            slot: slot,
            title: title,
            subtitle: subtitle,
            body: body,
            metadata: Self.decodeMetadata(metadataJSON),
            isFavorited: isFavorited,
            revealedAt: revealedAt
        )
    }

    var hasValidSlotValue: Bool {
        DailySlot(rawValue: slotRawValue) != nil
    }

    func update(from entry: BriefEntry) {
        sourceID = entry.sourceID
        slotRawValue = entry.slot.rawValue
        title = entry.title
        subtitle = entry.subtitle
        body = entry.body
        metadataJSON = Self.encodeMetadata(entry.metadata)
        isFavorited = entry.isFavorited
        revealedAt = entry.revealedAt
    }

    private static func encodeMetadata(_ metadata: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(metadata) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func slot(for date: Date, calendar: Calendar) -> DailySlot {
        DailyScheduler(calendar: calendar).slot(for: date)
    }

    private static func decodeMetadata(_ string: String) -> [String: String] {
        guard let data = string.data(using: .utf8),
              let metadata = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return metadata
    }
}
