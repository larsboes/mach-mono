import Foundation
import UserNotifications

public struct NotificationSink: BriefSink {
    public init() {}

    public func receive(_ entry: BriefEntry) async {
        let content = Self.content(for: entry)
        let request = UNNotificationRequest(
            identifier: "machbrief-\(entry.id.uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    public static func content(for entry: BriefEntry) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = BriefSourceRegistry.descriptor(for: entry.sourceID).displayName
        content.body = [entry.title, entry.subtitle].compactMap { $0 }.joined(separator: " - ")
        content.userInfo = ["url": "machbrief://open"]
        return content
    }
}

public struct BriefNotificationPlanItem: Equatable, Sendable {
    public let identifier: String
    public let date: Date
    public let title: String
    public let body: String

    public init(identifier: String, date: Date, title: String, body: String) {
        self.identifier = identifier
        self.date = date
        self.title = title
        self.body = body
    }
}

public enum BriefNotificationPlanner {
    public static func plan(for timeline: [BriefTimelineItem]) -> [BriefNotificationPlanItem] {
        timeline.map { item in
            BriefNotificationPlanItem(
                identifier: "machbrief-\(item.entry.slot.rawValue)",
                date: item.date,
                title: BriefSourceRegistry.descriptor(for: item.entry.sourceID).displayName,
                body: [item.entry.title, item.entry.subtitle].compactMap { $0 }.joined(separator: " - ")
            )
        }
    }
}
