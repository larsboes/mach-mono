import Foundation

public struct NotificationSink: BriefSink {
    public init() {}
    public func receive(_ entry: BriefEntry) async {
        _ = entry
    }
}
