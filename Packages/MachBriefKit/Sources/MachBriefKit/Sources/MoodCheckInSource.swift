import Foundation

public enum MoodRating: String, CaseIterable, Codable, Sendable {
    case awesome
    case good
    case okay
    case bad
    case terrible
}

public enum MoodMetadataKey: String, Sendable {
    case moodRating = "moodRating"
    case moodNote = "moodNote"
    case promptKind = "kind"

    public static let promptKindValue = "mood_prompt"
}

public struct MoodCheckInSource: BriefSource {
    public let id = "mood"
    public let displayName = "Mood Check-In"
    public let language: BriefLanguage

    public init(language: BriefLanguage = .defaultLanguage) {
        self.language = language
    }

    public func entry(for slot: DailySlot, date: Date) async -> BriefEntry {
        let isGerman = language.id == "de"

        return BriefEntry(
            sourceID: id,
            slot: slot,
            title: isGerman ? "Wie fühlst du dich?" : "How are you feeling?",
            subtitle: isGerman
                ? "Großartig / Gut / Okay / Schlecht / Furchtbar" : "Awesome / Good / Okay / Bad / Terrible",
            body: nil,
            metadata: [MoodMetadataKey.promptKind.rawValue: MoodMetadataKey.promptKindValue],
            revealedAt: date
        )
    }
}
