import Foundation

/// One comb filter with a lowpass in the feedback loop (Freeverb building block).
private struct Comb {
    var buffer: [Double]
    var index = 0
    var filterStore = 0.0
    var feedback = 0.5
    var damp1 = 0.5
    var damp2 = 0.5

    init(size: Int) { buffer = [Double](repeating: 0, count: max(1, size)) }

    @inline(__always)
    mutating func process(_ input: Double) -> Double {
        let output = buffer[index]
        filterStore = output * damp2 + filterStore * damp1
        buffer[index] = input + filterStore * feedback
        index += 1
        if index >= buffer.count { index = 0 }
        return output
    }

    mutating func clear() { for i in 0..<buffer.count { buffer[i] = 0 }; filterStore = 0; index = 0 }
}

/// One Schroeder allpass (Freeverb building block).
private struct Allpass {
    var buffer: [Double]
    var index = 0
    var feedback = 0.5

    init(size: Int) { buffer = [Double](repeating: 0, count: max(1, size)) }

    @inline(__always)
    mutating func process(_ input: Double) -> Double {
        let bufout = buffer[index]
        let output = -input + bufout
        buffer[index] = input + bufout * feedback
        index += 1
        if index >= buffer.count { index = 0 }
        return output
    }

    mutating func clear() { for i in 0..<buffer.count { buffer[i] = 0 }; index = 0 }
}

/// Mono Freeverb (Schroeder–Moorer: 8 comb + 4 allpass).
///
/// Deliberate deviation from the prototype's generated-impulse convolution
/// reverb (recorded in `tmp/ENGINE-SPEC.md`): Freeverb is lush, cheap, fully
/// owned, and deterministic — partitioned-FFT convolution is overkill for a
/// notch app. Buffers allocate once; `process` is allocation-free.
public final class Reverb {
    private var combs: [Comb]
    private var allpasses: [Allpass]

    private static let combTunings = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
    private static let allpassTunings = [556, 441, 341, 225]
    /// Input scale into the comb bank. Tuned against the v2 generated-impulse
    /// convolution (3 s, exp decay 2.6) on the Ambient preset A/B pass.
    private static let fixedGain = 0.020

    /// 0…1 — larger = longer tail.
    public var roomSize: Double = 0.88 { didSet { updateFeedback() } }
    /// 0…1 — larger = darker tail.
    public var damping: Double = 0.34 { didSet { updateDamping() } }

    public init(sampleRate: Double) {
        let scale = sampleRate / 44100.0
        combs = Self.combTunings.map { Comb(size: Int(Double($0) * scale)) }
        allpasses = Self.allpassTunings.map { Allpass(size: Int(Double($0) * scale)) }
        for i in 0..<allpasses.count { allpasses[i].feedback = 0.5 }
        updateFeedback()
        updateDamping()
    }

    private func updateFeedback() {
        // Longer tail than stock Freeverb — closer to the v2 3 s convolution decay.
        let fb = roomSize * 0.32 + 0.68
        for i in 0..<combs.count { combs[i].feedback = fb }
    }

    private func updateDamping() {
        let d = damping * 0.32
        for i in 0..<combs.count {
            combs[i].damp1 = d
            combs[i].damp2 = 1.0 - d
        }
    }

    public func reset() {
        for i in 0..<combs.count { combs[i].clear() }
        for i in 0..<allpasses.count { allpasses[i].clear() }
    }

    @inline(__always)
    public func process(_ input: Double) -> Double {
        let scaled = input * Self.fixedGain
        var out = 0.0
        for i in 0..<combs.count { out += combs[i].process(scaled) }
        for i in 0..<allpasses.count { out = allpasses[i].process(out) }
        return out
    }
}
