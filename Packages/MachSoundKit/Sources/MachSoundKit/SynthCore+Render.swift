import Foundation
import AVFoundation
import MachSoundDSP

extension SynthCore {
    /// Fill a (non-interleaved float32) buffer list with `frameCount` frames.
    /// Called from the `AVAudioSourceNode` render block — real-time, no allocations.
    func render(frameCount: Int, bufferList: UnsafeMutablePointer<AudioBufferList>) {
        let abl = UnsafeMutableAudioBufferListPointer(bufferList)
        let channelCount = abl.count

        let controls = snapshotControls()
        applyBlockControls(controls)
        drainEvents()

        let pool = voices.voices
        var blockSquareSum = 0.0

        for frame in 0..<frameCount {
            fireDueEvents(pool: pool)
            smoothGains(toward: controls)

            var dry = 0.0
            var ducked = 0.0
            var revSend = 0.0
            var delSend = 0.0
            for v in pool {
                let s = v.render()
                if s == 0 { continue }
                if v.duck { ducked += s } else { dry += s }
                if v.reverbSend > 0 { revSend += s * v.reverbSend }
                if v.delaySend > 0 { delSend += s * v.delaySend }
            }

            // Continuous noise beds.
            let vinyl = nextVinyl() * smVinylGain
            let texture = nextTexture() * smTextureGain
            dry += vinyl + texture
            revSend += texture

            // Sidechain duck, then effect returns.
            let duckGain = nextDuck()
            var master = dry + ducked * duckGain
            master += delayProcess(delSend) * 0.5      // matches v2 dwet
            master += reverbProcess(revSend) * smReverbReturn

            var out = compress(master * smMasterGain)
            if !out.isFinite { out = 0 }                 // never feed NaN/Inf to the device
            if out > 1.5 { out = 1.5 } else if out < -1.5 { out = -1.5 }
            blockSquareSum += out * out

            let fOut = Float(out)
            for ch in 0..<channelCount {
                if let mData = abl[ch].mData {
                    mData.assumingMemoryBound(to: Float.self)[frame] = fOut
                }
            }

            advanceFrame()
        }

        accumulateLevel(blockSquareSum, frames: frameCount)
    }

    private func drainEvents() {
        while pendingCount < pending.count, let e = eventQueue.dequeue() {
            pending[pendingCount] = e
            pendingCount += 1
        }
    }

    @inline(__always)
    private func fireDueEvents(pool: [Voice]) {
        let now = currentFrame
        var i = 0
        while i < pendingCount {
            if pending[i].startFrame <= now {
                let e = pending[i]
                voices.trigger(e)
                if e.triggersDuck { startDuck() }
                if e.beatKind != .none {
                    beatSink.push(BeatRecord(kind: e.beatKind, midi: e.beatMidi))
                }
                pendingCount -= 1
                pending[i] = pending[pendingCount]
            } else {
                i += 1
            }
        }
    }
}
