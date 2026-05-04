import Foundation

public protocol BriefStore: Sendable {
    func save(_ entry: BriefEntry) async
    func entries() async -> [BriefEntry]
}

public actor InMemoryBriefStore: BriefStore {
    private var values: [BriefEntry] = []

    public init() {}

    public func save(_ entry: BriefEntry) {
        values.insert(entry, at: 0)
    }

    public func entries() -> [BriefEntry] {
        values
    }
}
