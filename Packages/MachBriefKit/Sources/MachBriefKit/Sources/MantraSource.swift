import Foundation

public struct MantraSource: BriefSource {
    public let id = "mantra"
    public let displayName = "Mantra"

    private let scheduler: DailyScheduler
    private let mantras: [MantraItem]

    public init(scheduler: DailyScheduler = DailyScheduler(), mantras: [MantraItem]? = nil) {
        self.scheduler = scheduler
        self.mantras = mantras ?? BundleJSON.load("mantras", fallback: Self.fallbackMantras)
    }

    public func entry(for slot: DailySlot, date: Date) async -> BriefEntry {
        let seed = scheduler.stableSeed(for: date, slot: slot, sourceID: id)
        let item = mantras[seed % max(mantras.count, 1)]
        return BriefEntry(
            sourceID: id,
            slot: slot,
            title: item.text,
            subtitle: nil,
            body: nil,
            metadata: ["kind": "mantra"],
            revealedAt: date
        )
    }
}

public struct MantraItem: Codable, Sendable {
    public let text: String
}

extension MantraSource {
    static let fallbackMantras: [MantraItem] = [
        .init(text: "I can take one calm breath at a time."),
        .init(text: "Small progress still counts."),
        .init(text: "I choose steadiness over urgency."),
    ]
}
