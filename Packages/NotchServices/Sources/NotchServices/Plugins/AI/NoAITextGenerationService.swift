import Foundation

/// Deterministic fallback when no AI provider is available.
/// Returns clear error messages — never silently fails.
@MainActor
public final class NoAITextGenerationService: AITextGenerationService {
    public var isAvailable: Bool {
        get async { false }
    }

    public init() {}

    public func rewrite(_ text: String, style: AIRewriteStyle) async throws -> String {
        throw AIError.providerUnavailable(
            "No AI provider is configured for this device."
        )
    }

    public func rewriteStream(_ text: String, style: AIRewriteStyle) -> AsyncThrowingStream<String, Error> {
        unavailableStream()
    }

    public func summarize(_ text: String) async throws -> String {
        throw AIError.providerUnavailable(
            "No AI provider is configured for this device."
        )
    }

    public func summarizeStream(_ text: String) -> AsyncThrowingStream<String, Error> {
        unavailableStream()
    }

    public func section(_ text: String) async throws -> [String] {
        throw AIError.providerUnavailable(
            "No AI provider is configured for this device."
        )
    }

    public func draftIntro(topic: String, durationSeconds: Int) async throws -> String {
        throw AIError.providerUnavailable(
            "No AI provider is configured for this device."
        )
    }

    public func draftIntroStream(topic: String, durationSeconds: Int) -> AsyncThrowingStream<String, Error> {
        unavailableStream()
    }

    private func unavailableStream() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(
                throwing: AIError.providerUnavailable("No AI provider is configured for this device.")
            )
        }
    }
}
