import Foundation

public struct BriefSettings: Codable, Equatable, Sendable {
    public var enabledSourceIDs: Set<String>
    public var slotAssignments: [DailySlot: String]
    public var wordLanguageID: String
    public var customWordListPath: String?
    public var notificationsEnabled: Bool
    public var obsidianNotePath: String?
    public var vocabularyLevel: VocabularyLevel?

    public init(
        enabledSourceIDs: Set<String> = Set(BriefSourceRegistry.defaultSourceIDs),
        slotAssignments: [DailySlot: String] = BriefSettings.defaultSlotAssignments,
        wordLanguageID: String = BriefLanguage.defaultLanguage.id,
        customWordListPath: String? = nil,
        notificationsEnabled: Bool = false,
        obsidianNotePath: String? = nil,
        vocabularyLevel: VocabularyLevel? = nil
    ) {
        self.enabledSourceIDs = enabledSourceIDs
        self.slotAssignments = slotAssignments
        self.wordLanguageID = wordLanguageID
        self.customWordListPath = customWordListPath
        self.notificationsEnabled = notificationsEnabled
        self.obsidianNotePath = obsidianNotePath
        self.vocabularyLevel = vocabularyLevel
    }

    public static let defaultSlotAssignments: [DailySlot: String] = [
        .morning: "word",
        .midday: "fact",
        .afternoon: "mood",
        .evening: "quote",
    ]

    public func sourceID(for slot: DailySlot) -> String {
        let assigned = slotAssignments[slot] ?? Self.defaultSlotAssignments[slot] ?? "quote"
        if enabledSourceIDs.contains(assigned) {
            return assigned
        }
        return enabledSourceIDs.sorted().first ?? "quote"
    }

    public var wordLanguage: BriefLanguage {
        BriefLanguage.language(for: wordLanguageID)
    }
}

public struct BriefLanguage: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let dictionaryCode: String
    public let wordResourceName: String

    public init(id: String, displayName: String, dictionaryCode: String, wordResourceName: String) {
        self.id = id
        self.displayName = displayName
        self.dictionaryCode = dictionaryCode
        self.wordResourceName = wordResourceName
    }

    public static let english = BriefLanguage(id: "en", displayName: "English", dictionaryCode: "en", wordResourceName: "words")
    public static let german = BriefLanguage(id: "de", displayName: "Deutsch", dictionaryCode: "de", wordResourceName: "words_de")

    public static let supported: [BriefLanguage] = [.english, .german]

    public static var defaultLanguage: BriefLanguage {
        if Locale.current.language.languageCode?.identifier == "de" {
            return .german
        }
        return .english
    }

    public static func language(for id: String) -> BriefLanguage {
        supported.first { $0.id == id } ?? .english
    }
}

public enum BriefSettingsCoding {
    public static let userDefaultsKey = "machBrief.settings"

    public static func encode(_ settings: BriefSettings) -> String {
        guard let data = try? JSONEncoder().encode(settings) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    public static func decode(_ string: String) -> BriefSettings {
        guard let data = string.data(using: .utf8),
              let settings = try? JSONDecoder().decode(BriefSettings.self, from: data) else {
            return BriefSettings()
        }
        return settings
    }

    public static func load(from defaults: UserDefaults = MachSharedDefaults.suite) -> BriefSettings {
        decode(defaults.string(forKey: userDefaultsKey) ?? "")
    }

    public static func save(_ settings: BriefSettings, to defaults: UserDefaults = MachSharedDefaults.suite) {
        defaults.set(encode(settings), forKey: userDefaultsKey)
    }
}
