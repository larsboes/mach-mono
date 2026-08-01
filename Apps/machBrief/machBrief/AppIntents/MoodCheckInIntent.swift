import AppIntents
import MachBriefKit

struct MoodCheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "Log mood check-in"
    static var description = IntentDescription("Record a local-first mood check-in response for a brief entry.")

    @Parameter(title: "Mood")
    var mood: String

    init() {}

    init(mood: String) {
        self.mood = mood
    }

    func perform() async throws -> some IntentResult {
        guard Self.isSupportedMood(mood) else {
            throw MoodCheckInError.unsupportedMood
        }
        return .result()
    }
}

private extension MoodCheckInIntent {
    static let supportedMoodValues: [String] = MoodRating.allCases.map(\.rawValue)

    static func isSupportedMood(_ value: String) -> Bool {
        supportedMoodValues.contains(value.lowercased())
    }
}

private enum MoodCheckInError: Error, LocalizedError {
    case unsupportedMood

    var errorDescription: String? {
        "Supported values are: awesome, good, okay, bad, terrible."
    }
}
