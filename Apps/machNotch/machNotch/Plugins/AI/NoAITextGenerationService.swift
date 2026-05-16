import Foundation

/// Deterministic fallback when no AI provider is available.
/// Returns clear error messages — never silently fails.
@MainActor
final class NoAITextGenerationService: AITextGenerationService {
    var isAvailable: Bool {
        get async { false }
    }

    func rewrite(_ text: String, style: AIRewriteStyle) async throws -> String {
        throw AIError.providerUnavailable(
            "No AI provider is configured for this device."
        )
    }

    func summarize(_ text: String) async throws -> String {
        throw AIError.providerUnavailable(
            "No AI provider is configured for this device."
        )
    }

    func section(_ text: String) async throws -> [String] {
        throw AIError.providerUnavailable(
            "No AI provider is configured for this device."
        )
    }

    func draftIntro(topic: String, durationSeconds: Int) async throws -> String {
        throw AIError.providerUnavailable(
            "No AI provider is configured for this device."
        )
    }
}
