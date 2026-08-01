import Foundation

@MainActor
enum AITextGenerationServiceFactory {
    static func make(settings: any LocalAISettings) -> any AITextGenerationService {
        let router = LocalAIProviderRouter(
            foundationProvider: makeFoundationProvider(),
            omlxProvider: makeOMLXProvider(settings: settings)
        )

        return AvailabilityGatedAITextGenerationService(
            isEnabled: { settings.isAIEnabled },
            service: ProviderBackedAIService(provider: router)
        )
    }

    private static func makeFoundationProvider() -> (any AIProvider)? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return FoundationModelsProvider(client: AppleFoundationModelsClient())
        }
        #endif

        return nil
    }

    private static func makeOMLXProvider(settings: any LocalAISettings) -> (any AIProvider)? {
        let providerSettings = OMLXProviderSettings(settings: settings)
        guard providerSettings.isEnabled else { return nil }
        return OMLXProvider(settings: providerSettings)
    }
}

private final class AvailabilityGatedAITextGenerationService: AITextGenerationService {
    private let isEnabled: @MainActor () -> Bool
    private let service: any AITextGenerationService

    init(
        isEnabled: @escaping @MainActor () -> Bool,
        service: any AITextGenerationService
    ) {
        self.isEnabled = isEnabled
        self.service = service
    }

    var isAvailable: Bool {
        get async {
            guard isEnabled() else { return false }
            return await service.isAvailable
        }
    }

    func rewrite(_ text: String, style: AIRewriteStyle) async throws -> String {
        try ensureEnabled()
        return try await service.rewrite(text, style: style)
    }

    func rewriteStream(_ text: String, style: AIRewriteStyle) -> AsyncThrowingStream<String, Error> {
        streamIfEnabled { [self] in
            self.service.rewriteStream(text, style: style)
        }
    }

    func summarize(_ text: String) async throws -> String {
        try ensureEnabled()
        return try await service.summarize(text)
    }

    func summarizeStream(_ text: String) -> AsyncThrowingStream<String, Error> {
        streamIfEnabled { [self] in
            self.service.summarizeStream(text)
        }
    }

    func section(_ text: String) async throws -> [String] {
        try ensureEnabled()
        return try await service.section(text)
    }

    func draftIntro(topic: String, durationSeconds: Int) async throws -> String {
        try ensureEnabled()
        return try await service.draftIntro(topic: topic, durationSeconds: durationSeconds)
    }

    func draftIntroStream(topic: String, durationSeconds: Int) -> AsyncThrowingStream<String, Error> {
        streamIfEnabled { [self] in
            self.service.draftIntroStream(topic: topic, durationSeconds: durationSeconds)
        }
    }

    private func ensureEnabled() throws {
        guard isEnabled() else {
            throw AIError.featureDisabled
        }
    }

    private func streamIfEnabled(
        _ makeStream: @escaping @MainActor () -> AsyncThrowingStream<String, Error>
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                guard isEnabled() else {
                    continuation.finish(throwing: AIError.featureDisabled)
                    return
                }

                do {
                    for try await chunk in makeStream() {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

public struct LocalAIProviderRouter: AIProvider {
    public let id = "local-ai"
    public let name = "Local AI"

    private let foundationProvider: (any AIProvider)?
    private let omlxProvider: (any AIProvider)?

    public init(
        foundationProvider: (any AIProvider)?,
        omlxProvider: (any AIProvider)?
    ) {
        self.foundationProvider = foundationProvider
        self.omlxProvider = omlxProvider
    }

    public var isAvailable: Bool {
        get async {
            await selectedProvider() != nil
        }
    }

    public func generate(prompt: String, config: AIGenerationConfig) async throws -> String {
        guard let provider = await selectedProvider() else {
            throw AIError.providerUnavailable("No local AI provider is available.")
        }
        return try await provider.generate(prompt: prompt, config: config)
    }

    public func generateStream(prompt: String, config: AIGenerationConfig) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let provider = await selectedProvider() else {
                    continuation.finish(
                        throwing: AIError.providerUnavailable("No local AI provider is available.")
                    )
                    return
                }

                do {
                    for try await chunk in provider.generateStream(prompt: prompt, config: config) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func selectedProvider() async -> (any AIProvider)? {
        if let omlxProvider, await omlxProvider.isAvailable {
            return omlxProvider
        }

        if let foundationProvider, await foundationProvider.isAvailable {
            return foundationProvider
        }

        return nil
    }
}
