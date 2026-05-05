import Foundation

public struct WordItem: Codable, Sendable {
    public let word: String
    public let definition: String?
    public let partOfSpeech: String?
    public let phonetic: String?
    public let example: String?

    public init(
        word: String,
        definition: String? = nil,
        partOfSpeech: String? = nil,
        phonetic: String? = nil,
        example: String? = nil
    ) {
        self.word = word
        self.definition = definition
        self.partOfSpeech = partOfSpeech
        self.phonetic = phonetic
        self.example = example
    }
}

public struct WordSource: BriefSource {
    public let id = "word"
    public let displayName = "Word"

    private let scheduler: DailyScheduler
    private let words: [WordItem]
    private let dictionaryClient: any DictionaryAPIClientProtocol
    private let language: BriefLanguage

    public init(
        scheduler: DailyScheduler = DailyScheduler(),
        dictionaryClient: any DictionaryAPIClientProtocol = DictionaryAPIClient(),
        language: BriefLanguage = .english,
        words: [WordItem]? = nil,
        customWordsURL: URL? = nil
    ) {
        self.scheduler = scheduler
        self.dictionaryClient = dictionaryClient
        self.language = language
        self.words = words
            ?? Self.loadCustomWords(from: customWordsURL)
            ?? BundleJSON.load(language.wordResourceName, fallback: Self.fallbackWords(for: language))
    }

    public func entry(for slot: DailySlot, date: Date) async -> BriefEntry {
        let seed = scheduler.stableSeed(for: date, slot: slot, sourceID: id)
        let item = words[seed % max(words.count, 1)]
        let enriched = await dictionaryClient.lookup(word: item.word, languageCode: language.dictionaryCode)
        let partOfSpeech = enriched?.partOfSpeech ?? item.partOfSpeech
        let definition = enriched?.definition ?? item.definition
        let phonetic = enriched?.phonetic ?? item.phonetic
        let example = enriched?.example ?? item.example
        return BriefEntry(
            sourceID: id,
            slot: slot,
            title: item.word,
            subtitle: [partOfSpeech.map { "(\($0).)" }, phonetic].compactMap { $0 }.joined(separator: " "),
            body: definition,
            metadata: [
                "kind": "word",
                "language": language.id,
                "partOfSpeech": partOfSpeech ?? "",
                "phonetic": phonetic ?? "",
                "example": example ?? "",
            ].filter { !$0.value.isEmpty },
            revealedAt: date
        )
    }
}

extension WordSource {
    private static func loadCustomWords(from url: URL?) -> [WordItem]? {
        guard let url,
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([WordItem].self, from: data),
              !words.isEmpty else {
            return nil
        }
        return words
    }

    static func fallbackWords(for language: BriefLanguage) -> [WordItem] {
        switch language.id {
        case "de":
            return fallbackGermanWords
        default:
            return fallbackWords
        }
    }

    static let fallbackWords: [WordItem] = [
        .init(word: "serendipity", definition: "The occurrence of events by chance in a happy way.", partOfSpeech: "noun", phonetic: "/ˌserənˈdipədē/", example: "A little serendipity led her to the right book."),
        .init(word: "lucid", definition: "Expressed clearly; easy to understand.", partOfSpeech: "adjective", phonetic: "/ˈlo͞osəd/", example: "His lucid explanation made the idea feel simple."),
        .init(word: "steadfast", definition: "Resolutely or dutifully firm and unwavering.", partOfSpeech: "adjective", phonetic: "/ˈstedˌfast/", example: "She stayed steadfast through the long revision.")
    ]

    static let fallbackGermanWords: [WordItem] = [
        .init(word: "Fernweh", definition: "Die Sehnsucht nach fernen Orten und neuen Erfahrungen.", partOfSpeech: "Substantiv", phonetic: "/FEHRN-vey/", example: "Nach dem langen Winter spuerte sie wieder Fernweh."),
        .init(word: "achtsam", definition: "Bewusst aufmerksam, ruhig und gegenwaertig.", partOfSpeech: "Adjektiv", phonetic: "/AKHT-zahm/", example: "Ein achtsamer Morgen veraendert den ganzen Tag."),
        .init(word: "zuversichtlich", definition: "Von Vertrauen und positiver Erwartung getragen.", partOfSpeech: "Adjektiv", phonetic: "/TSOO-fer-zikh-tlikh/", example: "Er blieb zuversichtlich, obwohl der Weg offen war.")
    ]
}
