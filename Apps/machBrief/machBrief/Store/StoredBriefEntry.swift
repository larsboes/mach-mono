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
    var isFavorited: Bool
    var revealedAt: Date

    init(from entry: BriefEntry) {
        self.id = entry.id
        self.sourceID = entry.sourceID
        self.slotRawValue = entry.slot.rawValue
        self.title = entry.title
        self.subtitle = entry.subtitle
        self.body = entry.body
        self.isFavorited = entry.isFavorited
        self.revealedAt = entry.revealedAt
    }
}
