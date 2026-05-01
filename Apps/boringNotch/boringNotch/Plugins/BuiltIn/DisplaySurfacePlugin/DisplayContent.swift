import Foundation

enum DisplayContent: Sendable {
    case text(String)
    case markdown(String)
    case progress(label: String, value: Double)
    case keyValue([(String, String)])
    case clear

    var isEmpty: Bool {
        if case .clear = self { return true }
        return false
    }
}
