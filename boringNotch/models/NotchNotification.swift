import Defaults
import Foundation
import SwiftUI

enum NotchNotificationCategory: String, Codable, CaseIterable {
    case battery
    case calendar
    case shelf
    case system
    case info
    case app

    var icon: String {
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

    var displayName: String {
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

struct NotchNotification: Identifiable, Codable, Hashable, Defaults.Serializable {
    let id: UUID
    let title: String
    let message: String
    let date: Date
    let category: NotchNotificationCategory
    let sourceApp: String?
    var isRead: Bool

    init(
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
