import AVFoundation
import Foundation

@MainActor
@Observable
public final class MicrophoneMonitor {
    public var normalizedLevel: Double = 0.0  // Scaled 0.0 to 1.0 for UI binding

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?

    /// Builds nothing. `AVAudioRecorder` is created on the first
    /// `startMonitoring()` instead, so simply owning a `MicrophoneMonitor`
    /// never touches audio hardware and never raises the microphone prompt.
    public init() {}

    public func startMonitoring() {
        setupRecorderIfNeeded()
        guard let recorder = audioRecorder else {
            // Need permission or setup failed
            return
        }

        // Start recording (we don't save the file, just meter it)
        recorder.record()

        // Update 60 times a second for smooth visual bridging
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateLevel()
            }
        }
    }

    public func stopMonitoring() {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        normalizedLevel = 0.0
    }

    private func setupRecorderIfNeeded() {
        guard audioRecorder == nil else { return }

        // Just point to a throwaway temporary file
        let url = URL(fileURLWithPath: "/dev/null")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue,
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
        } catch {
            print("⚠️ [MicrophoneMonitor] Failed to initialize recorder: \(error.localizedDescription)")
        }
    }

    private func updateLevel() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()

        // peakPower(forChannel:) ranges from -160 (silence) to 0 (loudest)
        let decibels = recorder.averagePower(forChannel: 0)

        // Normalize
        // -50dB is basically quiet room noise for a mic. -10dB is loud talking.
        let minDb: Float = -50.0
        let maxDb: Float = -10.0

        var level = (decibels - minDb) / (maxDb - minDb)
        level = max(0.0, min(level, 1.0))

        // Add minimal easing so it doesn't jump instantly, keeping the beam buttery smooth
        // The beam glow scales on `normalizedLevel`, this creates a spring-like dampening
        let damping: Float = 0.3
        let current = Float(normalizedLevel)
        let smoothed = current + (level - current) * damping

        self.normalizedLevel = Double(smoothed)
    }

    deinit {
        // Timer uses [weak self] — fires harmlessly after dealloc.
        // Normal cleanup path: stopMonitoring() called by TeleprompterTimerManager.stop().
    }
}
