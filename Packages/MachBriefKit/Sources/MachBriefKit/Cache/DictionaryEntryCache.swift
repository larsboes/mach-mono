import Foundation

/// Persists dictionary-enriched WordItems so the API is hit once per word, not on every app launch.
public actor DictionaryEntryCache {
    public static let shared = DictionaryEntryCache()

    private var mem: [String: WordItem] = [:]
    private static let storageKey = "com.machNotch.brief.wordCache.v1"

    public init() {
        mem = Self.load()
    }

    public func lookup(word: String, languageCode: String) -> WordItem? {
        mem[key(word, languageCode)]
    }

    public func store(_ item: WordItem, languageCode: String) {
        mem[key(item.word, languageCode)] = item
        let snapshot = mem
        Task.detached(priority: .background) {
            Self.persist(snapshot)
        }
    }

    private func key(_ word: String, _ lang: String) -> String {
        "\(lang):\(word.lowercased())"
    }

    private static func load() -> [String: WordItem] {
        guard let data = MachSharedDefaults.suite.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: WordItem].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func persist(_ cache: [String: WordItem]) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        MachSharedDefaults.suite.set(data, forKey: storageKey)
    }
}
