import Defaults
import Foundation

public enum NotchNotificationCategory: String, Codable, CaseIterable {
    case battery
    case calendar
    case shelf
    case system
    case info
    case app

    public var icon: String {
        switch self {
        case .battery:
            return "battery.100"
        case .calendar:
            return "calendar"
        case .shelf:
            return "tray.full"
        case .system:
            return "gear"
        case .info:
            return "info.circle.fill"
        case .app:
            return "app.badge"
        }
    }

    public var displayName: String {
        switch self {
        case .battery:
            return "Battery"
        case .calendar:
            return "Calendar"
        case .shelf:
            return "Shelf"
        case .system:
            return "System"
        case .info:
            return "Info"
        case .app:
            return "App"
        }
    }
}

public struct NotchNotification: Identifiable, Codable, Hashable, Defaults.Serializable {
    public let id: UUID
    public let title: String
    public let message: String
    public let date: Date
    public let category: NotchNotificationCategory
    public let sourceApp: String?
    public var isRead: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        message: String,
        date: Date = Date(),
        category: NotchNotificationCategory,
        sourceApp: String? = nil,
        isRead: Bool = false
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.date = date
        self.category = category
        self.sourceApp = sourceApp
        self.isRead = isRead
    }
}
