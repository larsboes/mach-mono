import Foundation

/// Filter selector for a voice. UInt8-backed for the event queue.
public enum FilterKind: UInt8, Sendable {
    case none
    case lowpass
    case highpass
    case bandpass
}

/// RBJ "Audio EQ Cookbook" biquad, processed in Transposed Direct Form II.
///
/// This replaces AudioKit's `MoogLadder` (a colored, resonant 4-pole / 24 dB-oct
/// filter) which was the main reason the previous engine sounded too dark. A
/// 2-pole biquad matches Web Audio's `BiquadFilterNode`.
///
/// Coefficient recomputation calls `sin`/`cos`, so swept filters should call
/// `set` at a control rate (e.g. every 16–32 samples), not per sample.
public struct Biquad {
    private var b0 = 1.0, b1 = 0.0, b2 = 0.0
    private var a1 = 0.0, a2 = 0.0
    private var z1 = 0.0, z2 = 0.0
    public let sampleRate: Double

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    private mutating func setCoefficients(kind: FilterKind, freq: Double, q: Double) {
        let nyquist = sampleRate * 0.5
        let f0 = min(max(freq, 20.0), nyquist * 0.98)
        let qq = max(q, 0.001)
        let w0 = 2.0 * .pi * f0 / sampleRate
        let cosw0 = cos(w0)
        let sinw0 = sin(w0)
        let alpha = sinw0 / (2.0 * qq)
        let a0: Double

        switch kind {
        case .lowpass:
            b0 = (1.0 - cosw0) * 0.5
            b1 = 1.0 - cosw0
            b2 = (1.0 - cosw0) * 0.5
            a0 = 1.0 + alpha
            a1 = -2.0 * cosw0
            a2 = 1.0 - alpha
        case .highpass:
            b0 = (1.0 + cosw0) * 0.5
            b1 = -(1.0 + cosw0)
            b2 = (1.0 + cosw0) * 0.5
            a0 = 1.0 + alpha
            a1 = -2.0 * cosw0
            a2 = 1.0 - alpha
        case .bandpass:
            // Constant 0 dB peak gain.
            b0 = alpha
            b1 = 0.0
            b2 = -alpha
            a0 = 1.0 + alpha
            a1 = -2.0 * cosw0
            a2 = 1.0 - alpha
        case .none:
            b0 = 1.0; b1 = 0.0; b2 = 0.0; a0 = 1.0; a1 = 0.0; a2 = 0.0
        }

        let invA0 = 1.0 / a0
        b0 *= invA0; b1 *= invA0; b2 *= invA0
        a1 *= invA0; a2 *= invA0
    }

    public mutating func setLowpass(freq: Double, q: Double) { setCoefficients(kind: .lowpass, freq: freq, q: q) }
    public mutating func setHighpass(freq: Double, q: Double) { setCoefficients(kind: .highpass, freq: freq, q: q) }
    public mutating func setBandpass(freq: Double, q: Double) { setCoefficients(kind: .bandpass, freq: freq, q: q) }

    public mutating func set(kind: FilterKind, freq: Double, q: Double) {
        setCoefficients(kind: kind, freq: freq, q: q)
    }

    public mutating func reset() {
        z1 = 0; z2 = 0
    }

    @inline(__always)
    public mutating func process(_ x: Double) -> Double {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }
}
