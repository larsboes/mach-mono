import Foundation
import Observation

@MainActor
@Observable
final class DisplaySurfaceState {
    var content: DisplayContent = .clear
    private var ttlTask: Task<Void, Never>?

    nonisolated deinit {
        MainActor.assumeIsolated {
            ttlTask?.cancel()
        }
    }

    func setContent(_ content: DisplayContent, ttl: TimeInterval? = nil) {
        self.content = content

        ttlTask?.cancel()
        if let ttl = ttl {
            ttlTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(ttl * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.content = .clear
            }
        }
    }

    func clear() {
        ttlTask?.cancel()
        ttlTask = nil
        content = .clear
    }
}
