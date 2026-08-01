import Foundation

public struct EventModel: Equatable, Identifiable {
    public let id: String
    public let start: Date
    public let end: Date
    public let title: String
    public let location: String?
    public let notes: String?
    public let url: URL?
    public let isAllDay: Bool
    public let type: EventType
    public let calendar: CalendarModel
    public let participants: [Participant]
    public let timeZone: TimeZone?
    public let hasRecurrenceRules: Bool
    public let priority: Priority?

    public init(
        id: String,
        start: Date,
        end: Date,
        title: String,
        location: String? = nil,
        notes: String? = nil,
        url: URL? = nil,
        isAllDay: Bool,
        type: EventType,
        calendar: CalendarModel,
        participants: [Participant] = [],
        timeZone: TimeZone? = nil,
        hasRecurrenceRules: Bool = false,
        priority: Priority? = nil
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.title = title
        self.location = location
        self.notes = notes
        self.url = url
        self.isAllDay = isAllDay
        self.type = type
        self.calendar = calendar
        self.participants = participants
        self.timeZone = timeZone
        self.hasRecurrenceRules = hasRecurrenceRules
        self.priority = priority
    }
}

public enum AttendanceStatus: Comparable {
    case accepted
    case maybe
    case pending
    case declined
    case unknown

    private var comparisonValue: Int {
        switch self {
        case .accepted: return 1
        case .maybe: return 2
        case .declined: return 3
        case .pending: return 4
        case .unknown: return 5
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.comparisonValue < rhs.comparisonValue
    }
}

public enum EventType: Equatable {
    case event(AttendanceStatus)
    case birthday
    case reminder(completed: Bool)
}

public enum EventStatus: Equatable {
    case upcoming
    case inProgress
    case ended
}

extension EventType {
    public var isEvent: Bool { if case .event = self { return true } else { return false } }
    public var isBirthday: Bool { self ~= .birthday }
    public var isReminder: Bool { if case .reminder = self { return true } else { return false } }
}

extension EventModel {

    public var eventStatus: EventStatus {
        if start > Date() {
            return .upcoming
        } else if end > Date() {
            return .inProgress
        } else {
            return .ended
        }
    }

    public var attendance: AttendanceStatus {
        if case .event(let attendance) = type { return attendance } else { return .unknown }
    }

    public var isMeeting: Bool { !participants.isEmpty }

    public func calendarAppURL() -> URL? {

        guard let id = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }

        guard !type.isReminder else {
            return URL(string: "x-apple-reminderkit://remcdreminder/\(id)")
        }

        let date: String
        if hasRecurrenceRules {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if !isAllDay {
                formatter.timeZone = .init(secondsFromGMT: 0)
            }
            if let formattedDate = formatter.string(for: start) {
                date = "/\(formattedDate)"
            } else {
                return nil
            }
        } else {
            date = ""
        }
        return URL(string: "ical://ekevent\(date)/\(id)?method=show&options=more")
    }
}

public struct Participant: Hashable {
    public let name: String
    public let status: AttendanceStatus
    public let isOrganizer: Bool
    public let isCurrentUser: Bool
    
    public init(name: String, status: AttendanceStatus, isOrganizer: Bool, isCurrentUser: Bool) {
        self.name = name
        self.status = status
        self.isOrganizer = isOrganizer
        self.isCurrentUser = isCurrentUser
    }
}

public enum Priority {
    case high
    case medium
    case low
}
