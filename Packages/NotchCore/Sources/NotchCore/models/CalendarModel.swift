import Cocoa

public struct CalendarModel: Equatable {
    public let id: String
    public let account: String
    public let title: String
    public let color: NSColor
    public let isSubscribed: Bool
    public let isReminder: Bool  // true if this is a reminder calendar
    
    public init(id: String, account: String, title: String, color: NSColor, isSubscribed: Bool, isReminder: Bool) {
        self.id = id
        self.account = account
        self.title = title
        self.color = color
        self.isSubscribed = isSubscribed
        self.isReminder = isReminder
    }
}
