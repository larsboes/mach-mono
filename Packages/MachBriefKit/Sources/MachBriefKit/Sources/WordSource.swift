import Foundation

public struct WordItem: Codable, Sendable {
    public let word: String
    public let definition: String?
    public let partOfSpeech: String?
    public let phonetic: String?
    public let example: String?
    public let level: VocabularyLevel?

    public init(
        word: String,
        definition: String? = nil,
        partOfSpeech: String? = nil,
        phonetic: String? = nil,
        example: String? = nil,
        level: VocabularyLevel? = nil
    ) {
        self.word = word
        self.definition = definition
        self.partOfSpeech = partOfSpeech
        self.phonetic = phonetic
        self.example = example
        self.level = level
    }
}

public struct WordSource: BriefSource {
    public let id = "word"
    public let displayName = "Word"

    private let scheduler: DailyScheduler
    private let words: [WordItem]
    private let dictionaryClient: any DictionaryAPIClientProtocol
    private let entryCache: DictionaryEntryCache
    private let language: BriefLanguage

    public init(
        scheduler: DailyScheduler = DailyScheduler(),
        dictionaryClient: any DictionaryAPIClientProtocol = DictionaryAPIClient(),
        language: BriefLanguage = .english,
        vocabularyLevel: VocabularyLevel? = nil,
        entryCache: DictionaryEntryCache = .shared,
        words: [WordItem]? = nil,
        customWordsURL: URL? = nil
    ) {
        self.scheduler = scheduler
        self.dictionaryClient = dictionaryClient
        self.language = language
        self.entryCache = entryCache
        let allWords = words
            ?? Self.loadCustomWords(from: customWordsURL)
            ?? BundleJSON.load(language.wordResourceName, fallback: Self.fallbackWords(for: language))
        if let level = vocabularyLevel {
            let filtered = allWords.filter { $0.level == nil || $0.level == level }
            self.words = filtered.isEmpty ? allWords : filtered
        } else {
            self.words = allWords
        }
    }

    public func entry(for slot: DailySlot, date: Date) async -> BriefEntry {
        let seed = scheduler.stableSeed(for: date, slot: slot, sourceID: id)
        let item = words[seed % max(words.count, 1)]

        // 1. Cache hit — no network needed
        if let cached = await entryCache.lookup(word: item.word, languageCode: language.dictionaryCode) {
            return makeEntry(from: cached, slot: slot, date: date)
        }

        // 2. Live API — enriches definition, phonetic, part-of-speech, example
        let api = await dictionaryClient.lookup(word: item.word, languageCode: language.dictionaryCode)

        let resolved = WordItem(
            word: item.word,
            definition: api?.definition ?? item.definition,
            partOfSpeech: api?.partOfSpeech ?? item.partOfSpeech,
            phonetic: api?.phonetic ?? item.phonetic,
            example: api?.example ?? item.example
        )

        // Cache only when API succeeded — offline fallback stays uncached
        if api != nil {
            await entryCache.store(resolved, languageCode: language.dictionaryCode)
        }

        return makeEntry(from: resolved, slot: slot, date: date)
    }

    private func makeEntry(from item: WordItem, slot: DailySlot, date: Date) -> BriefEntry {
        BriefEntry(
            sourceID: id,
            slot: slot,
            title: item.word,
            subtitle: [item.partOfSpeech.map { "(\($0).)" }, item.phonetic]
                .compactMap { $0 }.joined(separator: " "),
            body: item.definition,
            metadata: [
                "kind": "word",
                "language": language.id,
                "partOfSpeech": item.partOfSpeech ?? "",
                "phonetic": item.phonetic ?? "",
                "example": item.example ?? "",
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
              !words.isEmpty else { return nil }
        return words
    }

    static func fallbackWords(for language: BriefLanguage) -> [WordItem] {
        language.id == "de" ? fallbackGermanWords : fallbackEnglishWords
    }

    static let fallbackEnglishWords: [WordItem] = [
        .init(word: "serendipity", definition: "The occurrence of events by chance in a happy way.", partOfSpeech: "noun"),
        .init(word: "lucid", definition: "Expressed clearly; easy to understand.", partOfSpeech: "adjective"),
        .init(word: "steadfast", definition: "Resolutely firm and unwavering.", partOfSpeech: "adjective"),
    ]

    static let fallbackGermanWords: [WordItem] = [
        .init(word: "Fernweh", definition: "Die Sehnsucht nach fernen Orten und neuen Erfahrungen.", partOfSpeech: "Substantiv"),
        .init(word: "achtsam", definition: "Bewusst aufmerksam, ruhig und gegenwärtig.", partOfSpeech: "Adjektiv"),
        .init(word: "Augenblick", definition: "Der gegenwärtige Moment; ein flüchtiger Zeitpunkt.", partOfSpeech: "Substantiv"),
    ]
}
