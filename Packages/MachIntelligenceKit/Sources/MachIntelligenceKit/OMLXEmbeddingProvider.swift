import Foundation

public struct OMLXEmbeddingProviderSettings: Codable, Equatable, Sendable {
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
}

public struct OMLXEmbeddingProvider: AIEmbeddingService, @unchecked Sendable {
    public let host: URL
    public let preferredModelId: String?
    public let allowNonLocalhostHost: Bool
    private let isEnabled: Bool

    public init(settings: OMLXEmbeddingProviderSettings) {
        self.host = settings.host
        self.preferredModelId = settings.preferredModelId
        self.allowNonLocalhostHost = settings.allowNonLocalhostHost
        self.isEnabled = settings.isEnabled
    }

    public func embedding(for text: String) async throws -> [Float] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard isEnabled else {
            throw AIEmbeddingError.featureDisabled
        }
        guard host.isAllowedOMLXHost(allowNonLocalhostHost) else {
            throw AIEmbeddingError.unavailable("oMLX host must be local unless non-localhost is allowed.")
        }

        let modelId = try await resolvedModelId()
        let body: [String: Any] = [
            "model": modelId,
            "input": trimmed
        ]

        do {
            let data = try await postJSON(path: "embeddings", body: body)
            let decoded = try JSONDecoder().decode(OpenAIEmbeddingResponse.self, from: data)

            guard let firstEmbedding = decoded.data.first?.embedding else {
                throw AIEmbeddingError.embeddingFailed("oMLX returned no embedding result.")
            }
            return firstEmbedding.map(Float.init)
        } catch {
            guard let error = error as? AIEmbeddingError else {
                throw AIEmbeddingError.embeddingFailed(error.localizedDescription)
            }
            throw error
        }
    }

    private func resolvedModelId() async throws -> String {
        if let preferredModelId {
            return preferredModelId
        }

        guard let firstModel = try await fetchModelIds().first else {
            throw AIEmbeddingError.unavailable("oMLX has no available models.")
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

    private func request(path: String, body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: endpoint(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func endpoint(_ path: String) -> URL {
        host.appendingPathComponent(path)
    }
}

private struct OpenAIModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }
    let data: [Model]
}

private struct OpenAIEmbeddingResponse: Decodable {
    struct Data: Decodable {
        let embedding: [Double]
    }
    let data: [Data]
}

private func validate(response: URLResponse, providerName: String) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
        throw AIEmbeddingError.unavailable("Invalid response from \(providerName)." )
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
        throw AIEmbeddingError.unavailable("\(providerName) returned status \(httpResponse.statusCode)." )
    }
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
