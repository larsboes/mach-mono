import Foundation

/// Feed-forward peak compressor on the master bus.
///
/// Matches the prototype's `DynamicsCompressorNode` settings exactly:
/// threshold −14 dB, ratio 4, and the Web Audio defaults for the parameters the
/// prototype leaves untouched — a **30 dB soft knee**, 3 ms attack, 250 ms
/// release. The wide knee + slow release are what keep it from audibly
/// "pumping" on every sidechained kick; tightening them (as an earlier pass
/// did) reintroduces per-beat breathing. Allocation-free.
public final class Compressor {
    public var thresholdDb: Double = -14.0
    public var ratio: Double = 4.0
    public var kneeDb: Double = 30.0
    public var makeupGain: Double = 1.0

    // Smoothed level detector (linear peak follower). Detecting on a *smoothed
    // level* — rather than the instantaneous sample — is essential: |x| crosses
    // zero every cycle, so a per-sample detector ripples the gain at the signal
    // frequency and adds a low buzz on bass/kick. Fast attack grabs peaks; slow
    // release holds gain steady through the troughs.
    private var levelEnv = 0.0
    private let attackCoef: Double
    private let releaseCoef: Double

    public init(sampleRate: Double, attackMs: Double = 3.0, releaseMs: Double = 250.0) {
        attackCoef = exp(-1.0 / max(1.0, attackMs * 0.001 * sampleRate))
        releaseCoef = exp(-1.0 / max(1.0, releaseMs * 0.001 * sampleRate))
    }

    public func reset() { levelEnv = 0 }

    @inline(__always)
    public func process(_ x: Double) -> Double {
        let level = abs(x)
        let coef = level > levelEnv ? attackCoef : releaseCoef
        levelEnv = coef * levelEnv + (1.0 - coef) * level

        let envDb = 20.0 * log10(max(levelEnv, 1e-9))
        let over = envDb - thresholdDb
        let slope = 1.0 - 1.0 / ratio

        var gainDb = 0.0
        if 2.0 * over >= kneeDb {
            gainDb = -slope * over                         // above the knee: full ratio
        } else if 2.0 * over > -kneeDb {
            let t = over + kneeDb / 2.0                     // soft knee (quadratic)
            gainDb = -slope * t * t / (2.0 * kneeDb)
        }

        let gain = pow(10.0, gainDb / 20.0) * makeupGain
        return x * gain
    }
}
