import Foundation

/// Domain-specific AI text generation service.
/// This is what plugins consume — high-level, semantic operations.
/// Decouples prompt engineering from plugin logic.
@MainActor
public protocol AITextGenerationService {
    var isAvailable: Bool { get async }

    /// Rewrite text for clarity and professionalism.
    func rewrite(_ text: String, style: AIRewriteStyle) async throws -> String
    func rewriteStream(_ text: String, style: AIRewriteStyle) -> AsyncThrowingStream<String, Error>

    /// Summarize text into concise bullet points.
    func summarize(_ text: String) async throws -> String
    func summarizeStream(_ text: String) -> AsyncThrowingStream<String, Error>

    /// Split text into logical sections with ## markers.
    func section(_ text: String) async throws -> [String]

    /// Generate a short introduction draft for a topic.
    func draftIntro(topic: String, durationSeconds: Int) async throws -> String
    func draftIntroStream(topic: String, durationSeconds: Int) -> AsyncThrowingStream<String, Error>
}

// MARK: - Rewrite Styles

public enum AIRewriteStyle: String, Codable, Sendable {
    case professional
    case concise
    case casual
    case formal
}
