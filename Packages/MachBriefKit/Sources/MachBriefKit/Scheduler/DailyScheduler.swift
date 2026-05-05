import Foundation

public struct DailyScheduler: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func slot(for date: Date) -> DailySlot {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 6..<12: return .morning
        case 12..<18: return .midday
        case 18..<24: return .afternoon
        default: return .evening
        }
    }

    public func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    public func date(for slot: DailySlot, on day: Date) -> Date {
        let start = startOfDay(for: day)
        return calendar.date(byAdding: .hour, value: slot.hour, to: start) ?? start
    }

    public func stableSeed(for date: Date, slot: DailySlot, sourceID: String) -> Int {
        let dayStart = startOfDay(for: date).timeIntervalSinceReferenceDate
        var hasher = Hasher()
        hasher.combine(Int(dayStart))
        hasher.combine(slot.rawValue)
        hasher.combine(sourceID)
        return abs(hasher.finalize())
    }
}
