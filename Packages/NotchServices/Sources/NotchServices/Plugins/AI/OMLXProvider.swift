import Foundation

public struct OMLXProviderSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var host: URL
    public var preferredModelId: String?
    public var allowNonLocalhostHost: Bool

    public init(
        isEnabled: Bool = false,
        host: URL = URL(string: "http://127.0.0.1:8000/v1")!,
        preferredModelId: String? = nil,
        allowNonLocalhostHost: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.host = host.normalizedOMLXBaseURL
        self.preferredModelId = preferredModelId?.nilIfBlank
        self.allowNonLocalhostHost = allowNonLocalhostHost
    }

    @MainActor
    public init(settings: any LocalAISettings) {
        self.init(
            isEnabled: settings.omlxProviderEnabled,
            host: URL(string: settings.omlxProviderHost) ?? URL(string: "http://127.0.0.1:8000/v1")!,
            preferredModelId: settings.omlxPreferredModelId,
            allowNonLocalhostHost: settings.omlxAllowNonLocalhostHost
        )
    }
}

public struct OMLXProvider: AIProvider {
    public let id = "omlx"
    public let name = "oMLX"

    private let settings: OMLXProviderSettings

    public init(settings: OMLXProviderSettings) {
        self.settings = settings
    }

    public var isAvailable: Bool {
        get async {
            guard settings.isEnabled, settings.host.isAllowedOMLXHost(settings.allowNonLocalhostHost) else {
                return false
            }

            return (try? await fetchModelIds()).map { !$0.isEmpty } ?? false
        }
    }

    public func generate(prompt: String, config: AIGenerationConfig) async throws -> String {
        let modelId = try await resolvedModelId()
        let body = chatCompletionsBody(
            prompt: prompt,
            config: config,
            modelId: modelId,
            stream: false
        )

        let data = try await postJSON(path: "chat/completions", body: body)
        let decoded = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data)

        guard let content = decoded.choices.first?.message.content else {
            throw AIError.generationFailed("oMLX returned no completion content.")
        }
        return content
    }

    public func generateStream(prompt: String, config: AIGenerationConfig) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let modelId = try await resolvedModelId()
                    let body = chatCompletionsBody(
                        prompt: prompt,
                        config: config,
                        modelId: modelId,
                        stream: true
                    )

                    let stream = try await postStreamingJSON(path: "chat/completions", body: body)
                    for try await line in stream.lines {
                        if let delta = Self.deltaContent(fromServerSentEventLine: line) {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func resolvedModelId() async throws -> String {
        guard settings.isEnabled else {
            throw AIError.featureDisabled
        }
        guard settings.host.isAllowedOMLXHost(settings.allowNonLocalhostHost) else {
            throw AIError.providerUnavailable("oMLX host must be localhost unless explicitly allowed.")
        }
        if let preferredModelId = settings.preferredModelId {
            return preferredModelId
        }

        guard let firstModel = try await fetchModelIds().first else {
            throw AIError.providerUnavailable("oMLX has no available models.")
        }
        return firstModel
    }

    private func fetchModelIds() async throws -> [String] {
        var request = URLRequest(url: endpoint("models"))
        request.httpMethod = "GET"
        request.timeoutInterval = 2

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, providerName: "oMLX")

        let decoded = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        return decoded.data.map(\.id)
    }

    private func postJSON(path: String, body: [String: Any]) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request(path: path, body: body))
        try validate(response: response, providerName: "oMLX")
        return data
    }

    private func postStreamingJSON(path: String, body: [String: Any]) async throws -> URLSession.AsyncBytes {
        let (bytes, response) = try await URLSession.shared.bytes(for: request(path: path, body: body))
        try validate(response: response, providerName: "oMLX")
        return bytes
    }

    private func request(path: String, body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: endpoint(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func endpoint(_ path: String) -> URL {
        settings.host.appendingPathComponent(path)
    }

    private func chatCompletionsBody(
        prompt: String,
        config: AIGenerationConfig,
        modelId: String,
        stream: Bool
    ) -> [String: Any] {
        [
            "model": modelId,
            "messages": [["role": "user", "content": prompt]],
            "stream": stream,
            "temperature": config.temperature,
            "max_tokens": config.maxTokens,
        ]
    }

    public static func deltaContent(fromServerSentEventLine line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard payload != "[DONE]", let data = payload.data(using: .utf8) else { return nil }

        return try? JSONDecoder()
            .decode(OpenAIChatCompletionChunk.self, from: data)
            .choices
            .first?
            .delta
            .content
    }
}

private func validate(response: URLResponse, providerName: String) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
        throw AIError.generationFailed("Invalid response from \(providerName).")
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
        throw AIError.providerUnavailable("\(providerName) returned status \(httpResponse.statusCode).")
    }
}

private struct OpenAIModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }

    let data: [Model]
}

private struct OpenAIChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct OpenAIChatCompletionChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }

        let delta: Delta
    }

    let choices: [Choice]
}

private extension URL {
    var normalizedOMLXBaseURL: URL {
        guard path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) != "v1" else {
            return self
        }
        return appendingPathComponent("v1")
    }

    func isAllowedOMLXHost(_ allowNonLocalhostHost: Bool) -> Bool {
        guard !allowNonLocalhostHost else { return true }

        let normalizedHost = host?.lowercased()
        return normalizedHost == "localhost" || normalizedHost == "127.0.0.1" || normalizedHost == "::1"
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
