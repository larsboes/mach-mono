import Foundation

public protocol AIEmbeddingService: Sendable {
    func embedding(for text: String) async throws -> [Float]
}

public enum AIEmbeddingError: LocalizedError, Sendable {
    case featureDisabled
    case unavailable(String)
    case embeddingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .featureDisabled:
            return "AI embedding is disabled"
        case .unavailable(let message):
            return "Embedding service unavailable: \(message)"
        case .embeddingFailed(let message):
            return "Embedding request failed: \(message)"
        }
    }
}

public struct NoAIEmbeddingService: AIEmbeddingService {
    public init() {}

    public func embedding(for text: String) async throws -> [Float] {
        throw AIEmbeddingError.featureDisabled
    }
}
