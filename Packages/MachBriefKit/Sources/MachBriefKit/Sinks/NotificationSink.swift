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

    public static let identifierPrefix = "machbrief-"

    public static func content(for entry: BriefEntry) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = BriefSourceRegistry.descriptor(for: entry.sourceID).displayName
        content.body = [entry.title, entry.subtitle].compactMap { $0 }.joined(separator: " - ")
        content.userInfo = ["url": "machbrief://open"]
        return content
    }

    public static func content(for planItem: BriefNotificationPlanItem) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = planItem.title
        content.body = planItem.body
        content.userInfo = ["url": "machbrief://open"]
        return content
    }

    public static func request(for planItem: BriefNotificationPlanItem) -> UNNotificationRequest {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: planItem.date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        return UNNotificationRequest(
            identifier: planItem.identifier,
            content: Self.content(for: planItem),
            trigger: trigger
        )
    }
}

public struct BriefNotificationPlanItem: Equatable, Sendable {
    public let identifier: String
    public let slot: DailySlot
    public let date: Date
    public let title: String
    public let body: String

    public init(slot: DailySlot, date: Date, title: String, body: String) {
        self.identifier = BriefNotificationPlanner.identifier(for: slot, date: date)
        self.slot = slot
        self.date = date
        self.title = title
        self.body = body
    }
}

public enum BriefNotificationPlanner {
    public static func identifier(for slot: DailySlot, date: Date) -> String {
        let timestamp = Int(date.timeIntervalSince1970)
        return "\(NotificationSink.identifierPrefix)\(slot.rawValue)-\(timestamp)"
    }

    public static func plan(for timeline: [BriefTimelineItem]) -> [BriefNotificationPlanItem] {
        timeline.map { item in
            BriefNotificationPlanItem(
                slot: item.entry.slot,
                date: item.date,
                title: BriefSourceRegistry.descriptor(for: item.entry.sourceID).displayName,
                body: [item.entry.title, item.entry.subtitle].compactMap { $0 }.joined(separator: " - ")
            )
        }
    }
}
