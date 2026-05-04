import Foundation

public enum MoodRating: String, CaseIterable, Codable, Sendable {
    case awesome
    case good
    case okay
    case bad
    case terrible
}

public struct MoodCheckInSource: BriefSource {
    public let id = "mood"
    public let displayName = "Mood Check-In"

    public init() {}

    public func entry(for slot: DailySlot, date: Date) async -> BriefEntry {
        BriefEntry(
            sourceID: id,
            slot: slot,
            title: "How are you feeling?",
            subtitle: "Awesome / Good / Okay / Bad / Terrible",
            body: nil,
            metadata: ["kind": "mood_prompt"],
            revealedAt: date
        )
    }
}
