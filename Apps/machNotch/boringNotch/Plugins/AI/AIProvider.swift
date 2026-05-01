import Foundation

// MARK: - Low-Level Transport Protocol

/// Low-level transport protocol for AI model backends (Ollama, MLX, Foundation Models).
/// Plugins should NOT use this directly — use `AITextGenerationService` instead.
protocol AIProvider: Sendable {
    var id: String { get }
    var name: String { get }
    var isAvailable: Bool { get async }

    func generate(prompt: String, config: AIGenerationConfig) async throws -> String
}

// MARK: - Generation Config

struct AIGenerationConfig: Codable, Sendable {
    var temperature: Double = 0.7
    var maxTokens: Int = 512
    var stopSequences: [String] = []
}

// MARK: - Errors

enum AIError: Error, LocalizedError {
    case providerUnavailable(String)
    case generationFailed(String)
    case featureDisabled

    var errorDescription: String? {
        switch self {
        case .providerUnavailable(let msg): return "AI Provider Unavailable: \(msg)"
        case .generationFailed(let msg): return "AI Generation Failed: \(msg)"
        case .featureDisabled: return "AI features are disabled in settings."
        }
    }
}
