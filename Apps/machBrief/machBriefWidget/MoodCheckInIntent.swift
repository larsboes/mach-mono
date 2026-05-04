import AppIntents

struct MoodCheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Mood"

    @Parameter(title: "Mood")
    var mood: String

    init() {}

    init(mood: String) {
        self.mood = mood
    }

    func perform() async throws -> some IntentResult {
        .result()
    }
}
