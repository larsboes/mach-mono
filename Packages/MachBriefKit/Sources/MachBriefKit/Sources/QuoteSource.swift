import Foundation

public struct QuoteSource: BriefSource {
    public let id = "quote"
    public let displayName = "Quote"

    private let scheduler: DailyScheduler
    private let quotes: [QuoteItem]

    public init(
        scheduler: DailyScheduler = DailyScheduler(),
        language: BriefLanguage = .english,
        quotes: [QuoteItem]? = nil
    ) {
        self.scheduler = scheduler
        let resourceName = language.id == "de" ? "quotes_de" : "quotes"
        self.quotes = quotes ?? BundleJSON.load(resourceName, fallback: Self.fallbackQuotes)
    }

    public func entry(for slot: DailySlot, date: Date) async -> BriefEntry {
        let seed = scheduler.stableSeed(for: date, slot: slot, sourceID: id)
        let item = quotes[seed % max(quotes.count, 1)]
        return BriefEntry(
            sourceID: id,
            slot: slot,
            title: item.text,
            subtitle: item.author,
            body: nil,
            metadata: ["kind": "quote"],
            revealedAt: date
        )
    }
}

public struct QuoteItem: Codable, Sendable {
    public let text: String
    public let author: String
}

extension QuoteSource {
    static let fallbackQuotes: [QuoteItem] = [
        .init(text: "Well done is better than well said.", author: "Benjamin Franklin"),
        .init(text: "The best way out is always through.", author: "Robert Frost"),
        .init(text: "Simplicity is the ultimate sophistication.", author: "Leonardo da Vinci"),
    ]
}
