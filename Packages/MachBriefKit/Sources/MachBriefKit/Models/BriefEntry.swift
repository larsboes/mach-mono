import Foundation

public struct BriefEntry: Codable, Identifiable, Sendable {
    public let id: UUID
    public let sourceID: String
    public let slot: DailySlot
    public let title: String
    public let subtitle: String?
    public let body: String?
    public var metadata: [String: String]
    public var isFavorited: Bool
    public let revealedAt: Date

    public init(
        id: UUID = UUID(),
        sourceID: String,
        slot: DailySlot,
        title: String,
        subtitle: String? = nil,
        body: String? = nil,
        metadata: [String: String] = [:],
        isFavorited: Bool = false,
        revealedAt: Date
    ) {
        self.id = id
        self.sourceID = sourceID
        self.slot = slot
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.metadata = metadata
        self.isFavorited = isFavorited
        self.revealedAt = revealedAt
    }
}
