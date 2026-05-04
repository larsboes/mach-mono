import Foundation

public protocol BriefSink: Sendable {
    func receive(_ entry: BriefEntry) async
}
