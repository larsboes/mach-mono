import Foundation

/// Fixed-size pool of pre-allocated voices.
///
/// Allocation is allocation-free at runtime: pick an inactive voice, else steal
/// the oldest (longest-playing) active voice — the one closest to finishing, so
/// stealing is least audible. The owning `SynthCore` iterates `voices` each
/// sample to sum the mix.
public final class VoicePool {
    public let voices: [Voice]

    public init(sampleRate: Double, count: Int) {
        voices = (0..<max(1, count)).map { _ in Voice(sampleRate: sampleRate) }
    }

    /// Find a voice for a new note and trigger it.
    public func trigger(_ event: NoteEvent) {
        let voice = allocate()
        voice.trigger(event)
    }

    private func allocate() -> Voice {
        var oldest = voices[0]
        var oldestAge = -1
        for v in voices {
            if !v.active { return v }
            if v.age > oldestAge {
                oldestAge = v.age
                oldest = v
            }
        }
        return oldest
    }

    public func silenceAll() {
        for v in voices { v.silence() }
    }

    public var activeCount: Int {
        var n = 0
        for v in voices where v.active { n += 1 }
        return n
    }
}
