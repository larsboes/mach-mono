import Foundation

// MARK: - Low-Level Transport Protocol

/// Low-level transport protocol for AI model backends (Foundation Models, oMLX).
/// Plugins should NOT use this directly — use `AITextGenerationService` instead.
public protocol AIProvider: Sendable {
    var id: String { get }
    var name: String { get }
    var isAvailable: Bool { get async }

    func generate(prompt: String, config: AIGenerationConfig) async throws -> String
    func generateStream(prompt: String, config: AIGenerationConfig) -> AsyncThrowingStream<String, Error>
}

public extension AIProvider {
    func generateStream(prompt: String, config: AIGenerationConfig) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await generate(prompt: prompt, config: config)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Generation Config

public struct AIGenerationConfig: Codable, Sendable {
    public var temperature: Double = 0.7
    public var maxTokens: Int = 512
    public var stopSequences: [String] = []

    public init(temperature: Double = 0.7, maxTokens: Int = 512, stopSequences: [String] = []) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stopSequences = stopSequences
    }
}

// MARK: - Errors

public enum AIError: Error, LocalizedError {
    case providerUnavailable(String)
    case generationFailed(String)
    case featureDisabled

    public var errorDescription: String? {
        switch self {
        case .providerUnavailable(let msg): return "AI Provider Unavailable: \(msg)"
        case .generationFailed(let msg): return "AI Generation Failed: \(msg)"
        case .featureDisabled: return "AI features are disabled in settings."
        }
    }
}
