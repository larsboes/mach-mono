import Foundation
import Observation

/// Standalone countdown timer that ticks once per second from a given duration down to zero.
///
/// Usage:
/// ```swift
/// let countdown = CountdownState()
/// countdown.start(duration: 3) { print("Go!") }
/// ```
///
/// - Thread-safety: All access is isolated to `@MainActor`.
/// - Cancellation: Call `cancel()` at any time to stop early and clean up.
@MainActor
@Observable
final class CountdownState {

    // MARK: - Published State

    /// Current value displayed by the countdown (seconds remaining).
    var countdownValue: Int = 0

    /// Whether a countdown is currently running.
    var isActive: Bool = false

    // MARK: - Private

    private var timer: Timer?
    private var completion: (() -> Void)?

    // MARK: - API

    /// Start countdown from `duration` seconds. Calls `onComplete` when reaching zero.
    ///
    /// A duration of `0` means "no countdown" — fires `onComplete` immediately.
    /// Starting a new countdown while one is already active cancels the previous one.
    func start(duration: Int, onComplete: @escaping () -> Void) {
        guard duration > 0 else {
            onComplete()
            return
        }

        cancel()
        self.completion = onComplete
        self.countdownValue = duration
        self.isActive = true

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    /// Cancel the running countdown, resetting all state.
    func cancel() {
        timer?.invalidate()
        timer = nil
        isActive = false
        countdownValue = 0
        completion = nil
    }

    // MARK: - Private Helpers

    private func tick() {
        countdownValue -= 1
        if countdownValue <= 0 {
            let onComplete = completion
            cancel()
            onComplete?()
        }
    }

    nonisolated deinit {
        // Timer cleanup is handled by cancel() when isActive is set to false.
        // deinit is a safety net — Timer.invalidate() is thread-safe.
    }
}
