import Foundation
import Observation

/// Coordination layer for AI providers.
/// Selects the best available provider and exposes a domain-level service.
/// Does NOT access singletons — receives `isEnabled` via settings injection.
@MainActor
@Observable
final class AIManager {
    private var providers: [String: any AIProvider] = [:]
    private(set) var activeProviderId: String?
    private let isEnabledProvider: () -> Bool

    /// The domain-level service plugins should use.
    /// Returns `NoAITextGenerationService` when disabled or no provider available.
    var textGeneration: any AITextGenerationService {
        guard isEnabledProvider() else {
            return NoAITextGenerationService()
        }

        guard let id = activeProviderId, let provider = providers[id] else {
            return NoAITextGenerationService()
        }

        return ProviderBackedAIService(provider: provider)
    }

    /// - Parameter isEnabled: Closure reading the setting. Avoids singleton coupling.
    init(isEnabled: @escaping () -> Bool = { true }) {
        self.isEnabledProvider = isEnabled
        registerProvider(OllamaProvider())
        activeProviderId = "ollama"
    }

    func registerProvider(_ provider: any AIProvider) {
        providers[provider.id] = provider
    }

    func setActiveProvider(id: String) {
        guard providers.keys.contains(id) else { return }
        activeProviderId = id
    }

    /// Check if the currently active provider is reachable.
    func checkAvailability() async -> Bool {
        guard isEnabledProvider() else { return false }
        guard let id = activeProviderId, let provider = providers[id] else { return false }
        return await provider.isAvailable
    }
}
