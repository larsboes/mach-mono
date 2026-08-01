import Foundation

/// Domain-level AI service backed by a low-level AIProvider.
/// Encapsulates all prompt engineering — callers use semantic methods.
@MainActor
public final class ProviderBackedAIService: AITextGenerationService {
    private let provider: any AIProvider

    public var isAvailable: Bool {
        get async {
            await provider.isAvailable
        }
    }

    public init(provider: any AIProvider) {
        self.provider = provider
    }

    public func rewrite(_ text: String, style: AIRewriteStyle) async throws -> String {
        let request = rewriteRequest(text, style: style)
        return try await provider.generate(prompt: request.prompt, config: request.config)
    }

    public func rewriteStream(_ text: String, style: AIRewriteStyle) -> AsyncThrowingStream<String, Error> {
        stream(for: rewriteRequest(text, style: style))
    }

    public func summarize(_ text: String) async throws -> String {
        let request = summarizeRequest(text)
        return try await provider.generate(prompt: request.prompt, config: request.config)
    }

    public func summarizeStream(_ text: String) -> AsyncThrowingStream<String, Error> {
        stream(for: summarizeRequest(text))
    }

    public func section(_ text: String) async throws -> [String] {
        let request = sectionRequest(text)
        let result = try await provider.generate(prompt: request.prompt, config: request.config)

        return
            result
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("##") }
            .map { $0.replacingOccurrences(of: "## ", with: "") }
    }

    public func draftIntro(topic: String, durationSeconds: Int) async throws -> String {
        let request = draftIntroRequest(topic: topic, durationSeconds: durationSeconds)
        return try await provider.generate(prompt: request.prompt, config: request.config)
    }

    public func draftIntroStream(topic: String, durationSeconds: Int) -> AsyncThrowingStream<String, Error> {
        stream(for: draftIntroRequest(topic: topic, durationSeconds: durationSeconds))
    }

    private func rewriteRequest(_ text: String, style: AIRewriteStyle) -> AITextGenerationRequest {
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

        return AITextGenerationRequest(
            prompt: prompt,
            config: AIGenerationConfig(temperature: 0.5, maxTokens: 1024)
        )
    }

    private func summarizeRequest(_ text: String) -> AITextGenerationRequest {
        let prompt = """
            Summarize the following text into 3-5 key bullet points. \
            Return ONLY the bullet points, each on its own line starting with "• ".

            ---
            \(text)
            ---
            """

        return AITextGenerationRequest(
            prompt: prompt,
            config: AIGenerationConfig(temperature: 0.3, maxTokens: 512)
        )
    }

    private func sectionRequest(_ text: String) -> AITextGenerationRequest {
        let prompt = """
            Split the following text into logical sections. \
            Return ONLY section headings, each on its own line, prefixed with "## ".

            ---
            \(text)
            ---
            """

        return AITextGenerationRequest(
            prompt: prompt,
            config: AIGenerationConfig(temperature: 0.3, maxTokens: 256)
        )
    }

    private func draftIntroRequest(topic: String, durationSeconds: Int) -> AITextGenerationRequest {
        let prompt = """
            Draft a \(durationSeconds)-second engaging introduction for a talk about: \(topic). \
            Return ONLY the draft script, nothing else. \
            Write naturally, as if spoken aloud.
            """

        return AITextGenerationRequest(
            prompt: prompt,
            config: AIGenerationConfig(temperature: 0.7, maxTokens: 512)
        )
    }

    private func stream(for request: AITextGenerationRequest) -> AsyncThrowingStream<String, Error> {
        provider.generateStream(prompt: request.prompt, config: request.config)
    }
}

private struct AITextGenerationRequest {
    let prompt: String
    let config: AIGenerationConfig
}
