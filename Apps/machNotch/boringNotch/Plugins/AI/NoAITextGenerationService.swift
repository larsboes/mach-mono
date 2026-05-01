import Foundation

/// Deterministic fallback when no AI provider is available.
/// Returns clear error messages — never silently fails.
@MainActor
final class NoAITextGenerationService: AITextGenerationService {
    var isAvailable: Bool { false }

    func rewrite(_ text: String, style: AIRewriteStyle) async throws -> String {
        throw AIError.providerUnavailable(
            "No AI provider available. Install Ollama (ollama.com) or use macOS 26+ for on-device AI."
        )
    }

    func summarize(_ text: String) async throws -> String {
        throw AIError.providerUnavailable(
            "No AI provider available. Install Ollama (ollama.com) or use macOS 26+ for on-device AI."
        )
    }

    func section(_ text: String) async throws -> [String] {
        throw AIError.providerUnavailable(
            "No AI provider available. Install Ollama (ollama.com) or use macOS 26+ for on-device AI."
        )
    }

    func draftIntro(topic: String, durationSeconds: Int) async throws -> String {
        throw AIError.providerUnavailable(
            "No AI provider available. Install Ollama (ollama.com) or use macOS 26+ for on-device AI."
        )
    }
}
