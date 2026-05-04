import Foundation

public enum DailySlot: Int, CaseIterable, Codable, Sendable {
    case morning = 0
    case midday = 1
    case afternoon = 2
    case evening = 3

    public var hour: Int {
        switch self {
        case .morning: return 6
        case .midday: return 12
        case .afternoon: return 18
        case .evening: return 0
        }
    }
}
