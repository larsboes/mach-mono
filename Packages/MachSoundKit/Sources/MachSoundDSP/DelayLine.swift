import Foundation

/// Feedback delay line with a one-pole lowpass in the feedback path.
///
/// Used by the lead voice's dotted-eighth send (delay time `spb * 0.75`,
/// feedback `0.32`), matching the prototype's `DelayNode` + feedback gain. The
/// buffer is allocated once; `process` is allocation-free.
public final class DelayLine {
    private var buffer: [Double]
    private let capacity: Int
    private var writeIndex = 0
    private var lpState = 0.0

    /// Delay length in samples, clamped to the buffer capacity.
    public var delaySamples: Int = 0 {
        didSet { delaySamples = min(max(delaySamples, 1), capacity - 1) }
    }
    /// Feedback amount [0, 1).
    public var feedback: Double = 0.32
    /// One-pole lowpass coefficient applied to the feedback signal [0, 1].
    public var dampingCoef: Double = 0.35

    public init(maxDelaySeconds: Double, sampleRate: Double) {
        capacity = max(2, Int(maxDelaySeconds * sampleRate) + 1)
        buffer = [Double](repeating: 0, count: capacity)
        delaySamples = capacity / 2
    }

    public func reset() {
        for i in 0..<capacity { buffer[i] = 0 }
        lpState = 0
        writeIndex = 0
    }

    /// Returns the delayed (wet) sample. The caller mixes dry + wet.
    @inline(__always)
    public func process(_ input: Double) -> Double {
        var readIndex = writeIndex - delaySamples
        if readIndex < 0 { readIndex += capacity }
        let delayed = buffer[readIndex]

        lpState += dampingCoef * (delayed - lpState)
        buffer[writeIndex] = input + lpState * feedback

        writeIndex += 1
        if writeIndex >= capacity { writeIndex = 0 }
        return delayed
    }
}
