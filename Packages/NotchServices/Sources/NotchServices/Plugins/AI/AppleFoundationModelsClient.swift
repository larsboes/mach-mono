import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, *)
struct AppleFoundationModelsClient: FoundationModelsClient {
    var availability: FoundationModelAvailability {
        get async {
            FoundationModelAvailability(SystemLanguageModel.default.availability)
        }
    }

    func generate(prompt: String, options: FoundationGenerationOptions) async throws -> String {
        let model = SystemLanguageModel.default
        let availability = FoundationModelAvailability(model.availability)
        guard availability.isAvailable else {
            throw AIError.providerUnavailable(availability.providerMessage)
        }

        let session = LanguageModelSession(model: model)
        let response = try await session.respond(
            to: prompt,
            options: options.foundationOptions
        )
        return response.content
    }

    func streamSnapshots(
        prompt: String,
        options: FoundationGenerationOptions
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let model = SystemLanguageModel.default
                    let availability = FoundationModelAvailability(model.availability)
                    guard availability.isAvailable else {
                        continuation.finish(throwing: AIError.providerUnavailable(availability.providerMessage))
                        return
                    }

                    let session = LanguageModelSession(model: model)
                    let responseStream = session.streamResponse(
                        to: prompt,
                        options: options.foundationOptions
                    )

                    for try await snapshot in responseStream {
                        continuation.yield(snapshot.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

@available(macOS 26.0, *)
extension FoundationModelAvailability {
    init(_ availability: SystemLanguageModel.Availability) {
        switch availability {
        case .available:
            self = .available
        case .unavailable(.deviceNotEligible):
            self = .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            self = .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            self = .modelNotReady
        @unknown default:
            self = .modelNotReady
        }
    }
}

@available(macOS 26.0, *)
extension FoundationGenerationOptions {
    var foundationOptions: GenerationOptions {
        GenerationOptions(
            temperature: temperature,
            maximumResponseTokens: maximumResponseTokens
        )
    }
}
#endif
