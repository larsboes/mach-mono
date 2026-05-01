import Foundation

/// Sliding-window rate limiter for API endpoints.
/// Thread-safe via NSLock. Periodic cleanup prevents unbounded memory growth.
final class APIRateLimiter: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [String: [Date]] = [:]
    private let limit: Int
    private let window: TimeInterval
    private var lastCleanup: Date = Date()
    private let cleanupInterval: TimeInterval = 60

    init(limit: Int = 10, window: TimeInterval = 1) {
        self.limit = limit
        self.window = window
    }

    func isAllowed(client: String) -> Bool {
        lock.withLock {
            let now = Date()

            // Periodic full cleanup — evict stale clients
            if now.timeIntervalSince(lastCleanup) >= cleanupInterval {
                requests = requests.filter { _, dates in
                    dates.contains { now.timeIntervalSince($0) < window }
                }
                lastCleanup = now
            }

            var clientRequests = requests[client] ?? []
            clientRequests.removeAll { now.timeIntervalSince($0) >= window }

            if clientRequests.count < limit {
                clientRequests.append(now)
                requests[client] = clientRequests
                return true
            }

            return false
        }
    }
}
