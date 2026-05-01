import SwiftUI

/// Concrete implementation of AppStateProviding
@MainActor
@Observable
final class BoringAppState: AppStateProviding {
    var isScreenLocked: Bool = false

    // Wrapper to handle non-Sendable observers safely
    private final class ObserverContainer: @unchecked Sendable {
        var observers: [Any] = []
    }
    
    @ObservationIgnored nonisolated private let observerContainer = ObserverContainer()

    init() {
        setupObservers()
    }

    deinit {
        let center = DistributedNotificationCenter.default()
        for observer in observerContainer.observers {
            center.removeObserver(observer)
        }
    }

    private func setupObservers() {
        let center = DistributedNotificationCenter.default()

        observerContainer.observers.append(center.addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenLocked = true
            }
        })

        observerContainer.observers.append(center.addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenLocked = false
            }
        })
    }
}
