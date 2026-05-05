import Foundation

public struct BriefSourceDescriptor: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let systemImage: String

    public init(id: String, displayName: String, systemImage: String) {
        self.id = id
        self.displayName = displayName
        self.systemImage = systemImage
    }
}

public enum BriefSourceRegistry {
    public static let descriptors: [BriefSourceDescriptor] = [
        .init(id: "word", displayName: "Word", systemImage: "textformat.abc"),
        .init(id: "fact", displayName: "Fact", systemImage: "lightbulb"),
        .init(id: "quote", displayName: "Quote", systemImage: "quote.bubble"),
        .init(id: "mantra", displayName: "Mantra", systemImage: "sparkles"),
        .init(id: "mood", displayName: "Mood", systemImage: "face.smiling"),
    ]

    public static let defaultSourceIDs = descriptors.map(\.id)

    public static func makeSources() -> [String: any BriefSource] {
        [
            "word": WordSource(),
            "fact": FactSource(),
            "quote": QuoteSource(),
            "mantra": MantraSource(),
            "mood": MoodCheckInSource(),
        ]
    }

    public static func descriptor(for sourceID: String) -> BriefSourceDescriptor {
        descriptors.first { $0.id == sourceID }
            ?? .init(id: sourceID, displayName: sourceID.capitalized, systemImage: "circle")
    }
}
