import Foundation

/// Concrete AIProvider using a local Ollama server.
struct OllamaProvider: AIProvider {
    let id = "ollama"
    let name = "Ollama"
    let model: String
    private let baseURL: URL

    init(model: String = "llama3", host: String = "http://127.0.0.1:11434") {
        self.model = model
        self.baseURL = URL(string: "\(host)/api/generate")!
    }

    var isAvailable: Bool {
        get async {
            // Quick health check — HEAD to /api/tags
            let tagsURL = baseURL.deletingLastPathComponent().appendingPathComponent("tags")
            var request = URLRequest(url: tagsURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 2

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                return (response as? HTTPURLResponse)?.statusCode == 200
            } catch {
                return false
            }
        }
    }

    func generate(prompt: String, config: AIGenerationConfig) async throws -> String {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": config.temperature,
                "num_predict": config.maxTokens,
                "stop": config.stopSequences
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.generationFailed("Invalid response from Ollama")
        }

        guard httpResponse.statusCode == 200 else {
            throw AIError.providerUnavailable("Ollama returned status \(httpResponse.statusCode)")
        }

        struct OllamaResponse: Decodable {
            let response: String
        }

        let decoded = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return decoded.response
    }
}
