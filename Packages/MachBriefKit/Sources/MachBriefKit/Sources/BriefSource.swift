import Foundation

public protocol BriefSource: Sendable {
    var id: String { get }
    var displayName: String { get }
    func entry(for slot: DailySlot, date: Date) async -> BriefEntry
}
