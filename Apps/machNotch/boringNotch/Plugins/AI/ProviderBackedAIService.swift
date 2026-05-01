import Foundation

/// Domain-level AI service backed by a low-level AIProvider.
/// Encapsulates all prompt engineering — callers use semantic methods.
@MainActor
final class ProviderBackedAIService: AITextGenerationService {
    private let provider: any AIProvider

    var isAvailable: Bool {
        // Synchronous approximation — true if we have a provider.
        // Actual availability checked per-call.
        true
    }

    init(provider: any AIProvider) {
        self.provider = provider
    }

    func rewrite(_ text: String, style: AIRewriteStyle) async throws -> String {
        let styleInstruction: String
        switch style {
        case .professional: styleInstruction = "professional and polished"
        case .concise: styleInstruction = "concise and to-the-point"
        case .casual: styleInstruction = "casual and conversational"
        case .formal: styleInstruction = "formal and authoritative"
        }

        let prompt = """
        Rewrite the following text to be \(styleInstruction). \
        Return ONLY the rewritten text, nothing else.

        ---
        \(text)
        ---
        """

        return try await provider.generate(
            prompt: prompt,
            config: AIGenerationConfig(temperature: 0.5, maxTokens: 1024)
        )
    }

    func summarize(_ text: String) async throws -> String {
        let prompt = """
        Summarize the following text into 3-5 key bullet points. \
        Return ONLY the bullet points, each on its own line starting with "• ".

        ---
        \(text)
        ---
        """

        return try await provider.generate(
            prompt: prompt,
            config: AIGenerationConfig(temperature: 0.3, maxTokens: 512)
        )
    }

    func section(_ text: String) async throws -> [String] {
        let prompt = """
        Split the following text into logical sections. \
        Return ONLY section headings, each on its own line, prefixed with "## ".

        ---
        \(text)
        ---
        """

        let result = try await provider.generate(
            prompt: prompt,
            config: AIGenerationConfig(temperature: 0.3, maxTokens: 256)
        )

        return result
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("##") }
            .map { $0.replacingOccurrences(of: "## ", with: "") }
    }

    func draftIntro(topic: String, durationSeconds: Int) async throws -> String {
        let prompt = """
        Draft a \(durationSeconds)-second engaging introduction for a talk about: \(topic). \
        Return ONLY the draft script, nothing else. \
        Write naturally, as if spoken aloud.
        """

        return try await provider.generate(
            prompt: prompt,
            config: AIGenerationConfig(temperature: 0.7, maxTokens: 512)
        )
    }
}
