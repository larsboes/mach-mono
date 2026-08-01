import Foundation

public enum FoundationModelAvailability: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady

    public var isAvailable: Bool {
        self == .available
    }

    public var providerMessage: String {
        switch self {
        case .available:
            "Foundation Models is available."
        case .deviceNotEligible:
            "This device is not eligible for Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence is not enabled."
        case .modelNotReady:
            "The on-device model is not ready."
        }
    }
}

public struct FoundationGenerationOptions: Equatable, Sendable {
    public let temperature: Double?
    public let maximumResponseTokens: Int?

    public init(config: AIGenerationConfig) {
        self.temperature = config.temperature
        self.maximumResponseTokens = config.maxTokens
    }
}

public protocol FoundationModelsClient: Sendable {
    var availability: FoundationModelAvailability { get async }

    func generate(prompt: String, options: FoundationGenerationOptions) async throws -> String
    func streamSnapshots(prompt: String, options: FoundationGenerationOptions) -> AsyncThrowingStream<String, Error>
}

public struct FoundationModelsProvider: AIProvider {
    public let id = "foundation-models"
    public let name = "Foundation Models"

    private let client: any FoundationModelsClient

    public init(client: any FoundationModelsClient) {
        self.client = client
    }

    public var isAvailable: Bool {
        get async {
            await client.availability.isAvailable
        }
    }

    public func generate(prompt: String, config: AIGenerationConfig) async throws -> String {
        let availability = await client.availability
        guard availability.isAvailable else {
            throw AIError.providerUnavailable(availability.providerMessage)
        }

        return try await client.generate(
            prompt: prompt,
            options: FoundationGenerationOptions(config: config)
        )
    }

    public func generateStream(prompt: String, config: AIGenerationConfig) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let availability = await client.availability
                guard availability.isAvailable else {
                    continuation.finish(throwing: AIError.providerUnavailable(availability.providerMessage))
                    return
                }

                var previousSnapshot = ""
                do {
                    let stream = client.streamSnapshots(
                        prompt: prompt,
                        options: FoundationGenerationOptions(config: config)
                    )

                    for try await snapshot in stream {
                        if let delta = Self.delta(from: snapshot, previous: &previousSnapshot) {
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

    public static func delta(from snapshot: String, previous: inout String) -> String? {
        defer { previous = snapshot }

        guard !snapshot.isEmpty else { return nil }
        guard snapshot.hasPrefix(previous) else { return snapshot }

        let delta = String(snapshot.dropFirst(previous.count))
        return delta.isEmpty ? nil : delta
    }
}
