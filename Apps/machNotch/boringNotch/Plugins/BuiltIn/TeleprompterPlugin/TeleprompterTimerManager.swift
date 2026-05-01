import Foundation

/// Manages the teleprompter scroll timer and microphone monitor lifecycle.
/// Extracted from TeleprompterState to isolate timer/resource concerns (SRP).
@MainActor
@Observable
final class TeleprompterTimerManager {
    let micMonitor = MicrophoneMonitor()

    private var timer: Timer?
    private(set) var lastUpdate: Date?

    var isRunning: Bool { timer != nil }

    /// Called every tick (~60fps). Passes current time to the handler.
    var onTick: ((Date) -> Void)?

    func start() {
        guard timer == nil else { return }
        lastUpdate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let now = Date()
                self.onTick?(now)
                self.lastUpdate = now
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastUpdate = nil
        micMonitor.stopMonitoring()
    }

    func resetLastUpdate() {
        lastUpdate = isRunning ? Date() : nil
    }

    deinit {
        // Timer retains its target weakly via [weak self] and will fire harmlessly.
        // No cleanup needed here — stop() is called by TeleprompterState.updateTimerState().
    }
}
