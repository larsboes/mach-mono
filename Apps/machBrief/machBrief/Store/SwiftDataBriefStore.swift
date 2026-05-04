import Foundation
import SwiftData
import MachBriefKit

@MainActor
final class SwiftDataBriefStore: BriefStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ entry: BriefEntry) async {
        context.insert(StoredBriefEntry(from: entry))
        try? context.save()
    }

    func entries() async -> [BriefEntry] {
        let descriptor = FetchDescriptor<StoredBriefEntry>(sortBy: [SortDescriptor(\.revealedAt, order: .reverse)])
        let stored = (try? context.fetch(descriptor)) ?? []
        return stored.compactMap { item in
            guard let slot = DailySlot(rawValue: item.slotRawValue) else { return nil }
            return BriefEntry(
                id: item.id,
                sourceID: item.sourceID,
                slot: slot,
                title: item.title,
                subtitle: item.subtitle,
                body: item.body,
                metadata: [:],
                isFavorited: item.isFavorited,
                revealedAt: item.revealedAt
            )
        }
    }
}
