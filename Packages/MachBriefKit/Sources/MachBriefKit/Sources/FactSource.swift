import Foundation

public struct FactSource: BriefSource {
    public let id = "fact"
    public let displayName = "Fact"

    private let scheduler: DailyScheduler
    private let facts: [FactItem]

    public init(scheduler: DailyScheduler = DailyScheduler(), facts: [FactItem]? = nil) {
        self.scheduler = scheduler
        self.facts = facts ?? BundleJSON.load("facts", fallback: Self.fallbackFacts)
    }

    public func entry(for slot: DailySlot, date: Date) async -> BriefEntry {
        let seed = scheduler.stableSeed(for: date, slot: slot, sourceID: id)
        let item = facts[seed % max(facts.count, 1)]
        return BriefEntry(
            sourceID: id,
            slot: slot,
            title: item.text,
            subtitle: item.category,
            body: nil,
            metadata: ["kind": "fact"],
            revealedAt: date
        )
    }
}

public struct FactItem: Codable, Sendable {
    public let text: String
    public let category: String
}

extension FactSource {
    static let fallbackFacts: [FactItem] = [
        .init(text: "Honey never spoils when sealed from moisture.", category: "science"),
        .init(text: "Octopuses have three hearts.", category: "nature"),
        .init(text: "The letter J was the last letter added to the English alphabet.", category: "language")
    ]
}
