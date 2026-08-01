import AVFoundation
import XCTest
@testable import MachSoundKit
import MachSoundDSP

/// Offline render harness: drive `SynthCore` without the audio device or the
/// timer, capture the mono output, and analyse it for doubled transients.
final class OfflineRenderTests: XCTestCase {

    private let sr = 48000.0

    private func makeCore() -> SynthCore {
        let q = EventQueue(capacity: 4096)
        let sink = BeatSink(capacity: 1024)
        let core = SynthCore(sampleRate: sr, eventQueue: q, beatSink: sink)
        // Dry, unity-gain, no effects so transients are clean to count.
        var c = SynthControls()
        c.masterGain = 1.0
        c.reverbReturnGain = 0.0
        c.vinylGain = 0.0
        c.textureGain = 0.0
        core.updateControls(c)
        core.reset()
        return core
    }

    private func render(_ core: SynthCore, frames: Int, block: Int = 512) -> [Float] {
        let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
        var out = [Float](); out.reserveCapacity(frames)
        var done = 0
        while done < frames {
            let n = min(block, frames - done)
            let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))!
            buf.frameLength = AVAudioFrameCount(n)
            core.render(frameCount: n, bufferList: buf.mutableAudioBufferList)
            let ch0 = buf.floatChannelData![0]
            for i in 0..<n { out.append(ch0[i]) }
            done += n
        }
        return out
    }

    /// Count onset transients via a peak-follower envelope (fast attack, ~50 ms
    /// release so it rides over the waveform period of low notes) plus a
    /// refractory gap so a single decaying hit can only count once.
    private func countOnsets(_ samples: [Float], threshold: Float = 0.03) -> Int {
        let releaseCoef = Float(exp(-1.0 / (0.050 * sr)))   // 50 ms
        let refractory = Int(0.08 * sr)                     // 80 ms min between onsets
        var env: Float = 0
        var onsets = 0
        var armed = true
        var sinceOnset = refractory
        for s in samples {
            let a = abs(s)
            env = a > env ? a : env * releaseCoef
            sinceOnset += 1
            if armed && env > threshold && sinceOnset >= refractory {
                onsets += 1
                armed = false
                sinceOnset = 0
            } else if !armed && env < threshold * 0.5 {
                armed = true
            }
            _ = sinceOnset
        }
        return onsets
    }

    func testSingleKickProducesSingleTransient() {
        let core = makeCore()
        var e = NoteEvent()
        e.startFrame = 1000
        e.waveform = .sine
        e.frequency = 44
        e.pitchStart = 150
        e.pitchEnd = 44
        e.pitchSweep = 0.15
        e.volume = 0.95
        e.attack = 0.001
        e.decay = 0.30
        core.eventQueue.enqueue(e)

        let samples = render(core, frames: Int(sr))   // 1 s
        let onsets = countOnsets(samples)
        XCTAssertEqual(onsets, 1, "one kick must produce exactly one transient, got \(onsets)")
    }

    func testFourKicksProduceFourTransients() {
        let core = makeCore()
        let step = Int64(0.25 * sr)
        for k in 0..<4 {
            var e = NoteEvent()
            e.startFrame = 1000 + Int64(k) * step
            e.waveform = .sine
            e.frequency = 44
            e.pitchStart = 150
            e.pitchEnd = 44
            e.pitchSweep = 0.15
            e.volume = 0.95
            e.attack = 0.001
            e.decay = 0.18
            core.eventQueue.enqueue(e)
        }
        let samples = render(core, frames: Int(1.5 * sr))
        let onsets = countOnsets(samples)
        XCTAssertEqual(onsets, 4, "four kicks must produce four transients, got \(onsets)")
    }

    /// Render several deterministic EDM bars via the real generators (EDM has no
    /// randomness), dump to /tmp, and report defect-oriented stats: NaN/Inf,
    /// DC offset, peak, and the noise floor (quietest 20 ms window). A persistent
    /// noise floor or any NaN points at a feedback-path defect (reverb/delay).
    func testEdmBarStats() {
        let engine = SoundEngine(context: SoundContext())
        engine.setMode(.edm)
        engine.setEnergy(0.7)

        let core = engine.synthCore
        var c = engine.currentControls(parameters: .defaults, mode: .edm)
        c.masterGain = 1.0
        core.updateControls(c)
        core.reset()

        let bpm = engine.getBPM()
        let stepFrames = Int64(60.0 / bpm / 4.0 * sr)
        let bars = 4
        for s in 0..<(16 * bars) {
            engine.executeStep(s, frame: 1000 + Int64(s) * stepFrames, mode: .edm, parameters: .defaults)
        }

        let frames = Int(Double(1000 + 16 * bars * Int(stepFrames)) + 0.5 * sr)
        let samples = render(core, frames: frames)
        writeWav(samples, to: "/tmp/edm_bar.wav")

        let nan = samples.contains { $0.isNaN || $0.isInfinite }
        let peak = samples.map { abs($0) }.max() ?? 0
        let dc = samples.reduce(0.0) { $0 + Double($1) } / Double(samples.count)

        // Window RMS over the ACTIVE region only (skip the ~21 ms leading silence
        // so the floor reflects what sits under the music, not pre-roll silence).
        let win = Int(0.02 * sr)
        let activeStart = 2000
        var minRMS = Double.greatestFiniteMagnitude
        var i = activeStart
        while i + win <= samples.count {
            var sum = 0.0
            for j in i..<(i + win) { sum += Double(samples[j]) * Double(samples[j]) }
            minRMS = min(minRMS, (sum / Double(win)).squareRoot())
            i += win
        }
        // Tail RMS: last 100 ms, long after the final event — should approach 0
        // unless reverb/delay/denormals ring forever.
        let tailStart = max(0, samples.count - Int(0.1 * sr))
        var tailSum = 0.0
        for j in tailStart..<samples.count { tailSum += Double(samples[j]) * Double(samples[j]) }
        let tailRMS = (tailSum / Double(samples.count - tailStart)).squareRoot()

        print("EDM stats: peak=\(peak) dc=\(dc) activeFloorRMS=\(minRMS) tailRMS=\(tailRMS) hasNaN=\(nan)")
        XCTAssertFalse(nan, "engine must not emit NaN/Inf")
        XCTAssertGreaterThan(peak, 0.01, "EDM should produce audio")
    }

    /// Offline A/B harness: render the first four bars of every preset with the
    /// real generators and verify each produces non-silent, finite audio.
    func testAllPresetsProduceFiniteAudio() throws {
        let modes: [SoundMode] = [.edm, .ambient, .lofi, .focus, .relax, .sleep]
        for mode in modes {
            let engine = SoundEngine(context: SoundContext())
            engine.setMode(mode)
            engine.setEnergy(0.7)
            if mode == .focus || mode == .relax || mode == .sleep {
                engine.setParameters(pace: 0.5, density: 0.5, brightness: 0.5,
                                       space: 0.5, pulse: 0.4, texture: 0.4)
            }

            let core = engine.synthCore
            var c = engine.currentControls(parameters: .defaults, mode: mode)
            c.masterGain = 1.0
            core.updateControls(c)
            core.reset()

            let bpm = engine.getBPM()
            let stepFrames = Int64(60.0 / bpm / 4.0 * sr)
            let bars = 4
            for s in 0..<(16 * bars) {
                engine.executeStep(s, frame: 1000 + Int64(s) * stepFrames, mode: mode, parameters: .defaults)
            }

            let frames = Int(Double(1000 + 16 * bars * Int(stepFrames)) + 0.5 * sr)
            let samples = render(core, frames: frames)
            let peak = samples.map { abs($0) }.max() ?? 0
            let nan = samples.contains { $0.isNaN || $0.isInfinite }
            XCTAssertFalse(nan, "\(mode) must not emit NaN/Inf")
            XCTAssertGreaterThan(peak, 0.005, "\(mode) should produce audible output")
        }
    }

    /// Verify reverb controls match the native v2 preset table for parity work.
    func testReverbControlsMatchPrototype() {
        let engine = SoundEngine(context: SoundContext())
        let params = SoundEngineParameters.defaults

        engine.setMode(.edm)
        var c = engine.currentControls(parameters: params, mode: .edm)
        XCTAssertEqual(c.reverbReturnGain, 0.16, accuracy: 1e-9)
        XCTAssertEqual(c.reverbRoom, 0.78, accuracy: 1e-9)
        XCTAssertEqual(c.reverbDamping, 0.48, accuracy: 1e-9)

        engine.setMode(.ambient)
        c = engine.currentControls(parameters: params, mode: .ambient)
        XCTAssertEqual(c.reverbReturnGain, 0.55, accuracy: 1e-9)
        XCTAssertEqual(c.reverbRoom, 0.94, accuracy: 1e-9)
        XCTAssertEqual(c.reverbDamping, 0.28, accuracy: 1e-9)

        engine.setMode(.lofi)
        c = engine.currentControls(parameters: params, mode: .lofi)
        XCTAssertEqual(c.reverbReturnGain, 0.22, accuracy: 1e-9)
        XCTAssertEqual(c.reverbRoom, 0.82, accuracy: 1e-9)
        XCTAssertEqual(c.reverbDamping, 0.42, accuracy: 1e-9)

        engine.setMode(.focus)
        engine.setParameters(pace: 0.5, density: 0.5, brightness: 0.5, space: 0.5, pulse: 0.4, texture: 0.4)
        c = engine.currentControls(parameters: params, mode: .focus)
        XCTAssertEqual(c.reverbReturnGain, 0.4, accuracy: 1e-9)
        XCTAssertEqual(c.reverbRoom, 0.90, accuracy: 1e-9)
        XCTAssertEqual(c.reverbDamping, 0.32, accuracy: 1e-9)

        engine.setMode(.relax)
        engine.setParameters(pace: 0.5, density: 0.5, brightness: 0.5, space: 0.5, pulse: 0.4, texture: 0.4)
        c = engine.currentControls(parameters: params, mode: .relax)
        XCTAssertEqual(c.reverbReturnGain, 0.4, accuracy: 1e-9)
        XCTAssertEqual(c.reverbRoom, 0.90, accuracy: 1e-9)
        XCTAssertEqual(c.reverbDamping, 0.32, accuracy: 1e-9)

        engine.setMode(.sleep)
        engine.setParameters(pace: 0.5, density: 0.5, brightness: 0.5, space: 0.5, pulse: 0.4, texture: 0.4)
        c = engine.currentControls(parameters: params, mode: .sleep)
        XCTAssertEqual(c.reverbReturnGain, 0.4, accuracy: 1e-9)
        XCTAssertEqual(c.reverbRoom, 0.90, accuracy: 1e-9)
        XCTAssertEqual(c.reverbDamping, 0.32, accuracy: 1e-9)
    }

    private func writeWav(_ samples: [Float], to path: String) {
        let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        guard let file = try? AVAudioFile(forWriting: URL(fileURLWithPath: path),
                                          settings: format.settings) else { return }
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buf.frameLength = AVAudioFrameCount(samples.count)
        let ptr = buf.floatChannelData![0]
        for i in 0..<samples.count { ptr[i] = samples[i] }
        try? file.write(from: buf)
    }
}
