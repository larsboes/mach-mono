import Foundation

public enum VocabularyLevel: String, CaseIterable, Codable, Sendable {
    case intermediate
    case advanced
    case expert

    public var displayName: String {
        switch self {
        case .intermediate: return "Intermediate"
        case .advanced:     return "Advanced"
        case .expert:       return "Expert"
        }
    }

    public var description: String {
        switch self {
        case .intermediate: return "Challenging but familiar"
        case .advanced:     return "Less common, precise words"
        case .expert:       return "Rare, literary, obsessive"
        }
    }

    public var systemImage: String {
        switch self {
        case .intermediate: return "books.vertical"
        case .advanced:     return "graduationcap"
        case .expert:       return "bolt.fill"
        }
    }
}
