import Foundation

public struct WordItem: Codable, Sendable {
    public let word: String
    public let definition: String?
    public let partOfSpeech: String?
}

public struct WordSource: BriefSource {
    public let id = "word"
    public let displayName = "Word"

    private let scheduler: DailyScheduler
    private let words: [WordItem]
    private let dictionaryClient: any DictionaryAPIClientProtocol

    public init(
        scheduler: DailyScheduler = DailyScheduler(),
        dictionaryClient: any DictionaryAPIClientProtocol = DictionaryAPIClient(),
        words: [WordItem]? = nil
    ) {
        self.scheduler = scheduler
        self.dictionaryClient = dictionaryClient
        self.words = words ?? BundleJSON.load("words", fallback: Self.fallbackWords)
    }

    public func entry(for slot: DailySlot, date: Date) async -> BriefEntry {
        let seed = scheduler.stableSeed(for: date, slot: slot, sourceID: id)
        let item = words[seed % max(words.count, 1)]
        let enriched = await dictionaryClient.lookup(word: item.word)
        return BriefEntry(
            sourceID: id,
            slot: slot,
            title: item.word,
            subtitle: enriched?.partOfSpeech ?? item.partOfSpeech,
            body: enriched?.definition ?? item.definition,
            metadata: ["kind": "word"],
            revealedAt: date
        )
    }
}

extension WordSource {
    static let fallbackWords: [WordItem] = [
        .init(word: "serendipity", definition: "The occurrence of events by chance in a happy way.", partOfSpeech: "noun"),
        .init(word: "lucid", definition: "Expressed clearly; easy to understand.", partOfSpeech: "adjective"),
        .init(word: "steadfast", definition: "Resolutely or dutifully firm and unwavering.", partOfSpeech: "adjective")
    ]
}
