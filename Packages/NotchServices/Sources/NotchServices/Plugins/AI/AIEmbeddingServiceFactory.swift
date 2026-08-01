import Foundation

import MachIntelligenceKit
import NotchCore

@MainActor
enum AIEmbeddingServiceFactory {
    static func make(settings: any LocalAISettings) -> any AIEmbeddingService {
        guard settings.isAIEnabled else {
            return NoAIEmbeddingService()
        }

        guard let provider = makeOMLXProvider(settings: settings) else {
            return NoAIEmbeddingService()
        }

        return AvailabilityGatedAIEmbeddingService(
            isEnabled: { settings.isAIEnabled },
            service: provider
        )
    }

    private static func makeOMLXProvider(settings: any LocalAISettings) -> OMLXEmbeddingProvider? {
        let providerSettings = OMLXEmbeddingProviderSettings(
            isEnabled: settings.omlxProviderEnabled,
            host: URL(string: settings.omlxProviderHost) ?? URL(string: "http://127.0.0.1:8000/v1")!,
            preferredModelId: settings.omlxPreferredModelId,
            allowNonLocalhostHost: settings.omlxAllowNonLocalhostHost
        )

        if !providerSettings.isEnabled || !providerSettings.host.isAllowedOMLXHost(
            providerSettings.allowNonLocalhostHost
        ) {
            return nil
        }

        return OMLXEmbeddingProvider(settings: providerSettings)
    }
}

private extension URL {
    func isAllowedOMLXHost(_ allowNonLocalhostHost: Bool) -> Bool {
        guard !allowNonLocalhostHost else { return true }
        let normalizedHost = host?.lowercased()
        return normalizedHost == "localhost" || normalizedHost == "127.0.0.1" || normalizedHost == "::1"
    }
}

@MainActor
private final class AvailabilityGatedAIEmbeddingService: AIEmbeddingService {
    private let isEnabled: @MainActor () -> Bool
    private let service: any AIEmbeddingService

    init(
        isEnabled: @MainActor @escaping () -> Bool,
        service: any AIEmbeddingService
    ) {
        self.isEnabled = isEnabled
        self.service = service
    }

    public func embedding(for text: String) async throws -> [Float] {
        guard isEnabled() else {
            throw AIEmbeddingError.featureDisabled
        }
        return try await service.embedding(for: text)
    }
}
