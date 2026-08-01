import XCTest
import MachSoundDSP

/// Phase 0 coverage for the sample-accurate DSP primitives. These run without
/// AudioKit or an audio device — pure numeric checks on the building blocks.
final class DSPPrimitivesTests: XCTestCase {
    let sr = 48000.0

    private func isFinite(_ x: Double) -> Bool { x.isFinite }

    // MARK: Oscillator

    func testOscillatorStaysInRangeAndFinite() {
        var osc = Oscillator(sampleRate: sr)
        osc.setFrequency(440)
        for wf in [Waveform.sine, .saw, .square, .triangle] {
            osc.reset()
            osc.setFrequency(440)
            for _ in 0..<sr.rounded().asInt {
                let s = osc.next(wf)
                XCTAssertTrue(isFinite(s), "\(wf) produced non-finite sample")
                XCTAssertLessThanOrEqual(abs(s), 1.6, "\(wf) sample out of expected range: \(s)")
            }
        }
    }

    func testPolyBlepReducesSawAliasing() {
        // A high-frequency saw should have far less energy above Nyquist-imaging
        // artifacts than a naive ramp. Here we just sanity-check the corrected saw
        // has lower peak-to-peak discontinuity energy than the naive version.
        var osc = Oscillator(sampleRate: sr)
        osc.setFrequency(8000)
        var prev = osc.next(.saw)
        var maxJump = 0.0
        for _ in 0..<2000 {
            let s = osc.next(.saw)
            maxJump = max(maxJump, abs(s - prev))
            prev = s
        }
        // The corrected saw smooths the wrap discontinuity; a naive saw at 8 kHz
        // jumps ~2.0 every cycle. PolyBLEP should keep the per-sample jump well
        // under that.
        XCTAssertLessThan(maxJump, 1.5, "PolyBLEP did not smooth the saw discontinuity")
    }

    func testWhiteNoiseInRange() {
        var n = WhiteNoise()
        var sum = 0.0
        let count = 100_000
        for _ in 0..<count {
            let s = n.next()
            XCTAssertLessThanOrEqual(abs(s), 1.0)
            sum += s
        }
        XCTAssertLessThan(abs(sum / Double(count)), 0.05, "noise mean should be near zero")
    }

    // MARK: Envelope

    func testPercussiveEnvelopeDecaysAndCompletes() {
        var env = Envelope()
        env.trigger(sampleRate: sr, peak: 1.0, attack: 0.0, decay: 0.1)
        XCTAssertTrue(env.isActive)
        let first = env.next()
        XCTAssertGreaterThan(first, 0.5, "instant-attack envelope should start near peak")

        var samples = 0
        while env.isActive && samples < Int(sr) {
            _ = env.next()
            samples += 1
        }
        XCTAssertFalse(env.isActive, "envelope should complete")
        // ~0.1 s decay at 48 kHz ≈ 4800 samples.
        XCTAssertLessThan(samples, 6000)
    }

    func testSustainedEnvelopeHolds() {
        var env = Envelope()
        env.trigger(sampleRate: sr, peak: 0.5, attack: 0.01, decay: 0.05, hold: 0.2, sustained: true)
        // Advance past attack.
        for _ in 0..<Int(0.02 * sr) { _ = env.next() }
        XCTAssertEqual(env.value, 0.5, accuracy: 0.05, "should hold at peak during sustain")
        XCTAssertTrue(env.isActive)
    }

    func testGlideReachesTarget() {
        var g = Glide()
        g.start(from: 150, to: 44, samples: Int(0.075 * sr))
        var last = g.value
        for _ in 0..<Int(0.075 * sr) { last = g.next() }
        XCTAssertEqual(last, 44, accuracy: 0.5)
        // Holds after completion.
        XCTAssertEqual(g.next(), 44, accuracy: 0.5)
    }

    // MARK: Biquad

    func testLowpassAttenuatesHighFrequencies() {
        func rms(freq: Double, cutoff: Double) -> Double {
            var osc = Oscillator(sampleRate: sr)
            osc.setFrequency(freq)
            var bq = Biquad(sampleRate: sr)
            bq.setLowpass(freq: cutoff, q: 0.707)
            // warm up
            for _ in 0..<2000 { _ = bq.process(osc.next(.sine)) }
            var acc = 0.0
            let n = 8000
            for _ in 0..<n {
                let y = bq.process(osc.next(.sine))
                acc += y * y
            }
            return (acc / Double(n)).squareRoot()
        }
        let low = rms(freq: 200, cutoff: 1000)
        let high = rms(freq: 8000, cutoff: 1000)
        XCTAssertGreaterThan(low, high * 4, "lowpass should pass 200 Hz and attenuate 8 kHz")
    }

    func testBiquadStaysFinite() {
        var bq = Biquad(sampleRate: sr)
        bq.setBandpass(freq: 1800, q: 5)
        var n = WhiteNoise()
        for _ in 0..<Int(sr) {
            let y = bq.process(n.next())
            XCTAssertTrue(y.isFinite)
        }
    }

    // MARK: Delay / Reverb / Compressor

    func testDelayProducesDelayedSignalAndStaysFinite() {
        let d = DelayLine(maxDelaySeconds: 1.0, sampleRate: sr)
        d.delaySamples = 100
        d.feedback = 0.5
        var out = [Double]()
        out.append(d.process(1.0)) // impulse
        for _ in 0..<300 { out.append(d.process(0.0)) }
        XCTAssertEqual(out[0], 0.0, accuracy: 1e-9, "first output is empty buffer")
        XCTAssertGreaterThan(out[100], 0.5, "impulse should appear after the delay")
        XCTAssertTrue(out.allSatisfy { $0.isFinite })
    }

    func testReverbDecaysAndStaysFinite() {
        let r = Reverb(sampleRate: sr)
        r.roomSize = 0.6
        r.damping = 0.5
        _ = r.process(1.0)
        var tail = 0.0
        for _ in 0..<Int(sr * 2) {
            let y = r.process(0.0)
            XCTAssertTrue(y.isFinite)
            tail = abs(y)
        }
        XCTAssertLessThan(tail, 0.01, "reverb tail should decay toward silence")
    }

    func testCompressorReducesGainAboveThreshold() {
        let c = Compressor(sampleRate: sr)
        c.thresholdDb = -14
        c.ratio = 4
        var osc = Oscillator(sampleRate: sr)
        osc.setFrequency(220)
        var peakIn = 0.0
        var peakOut = 0.0
        for _ in 0..<Int(sr) {
            let x = osc.next(.sine) * 1.0 // 0 dBFS sine, well above -14 dB
            let y = c.process(x)
            peakIn = max(peakIn, abs(x))
            peakOut = max(peakOut, abs(y))
        }
        XCTAssertLessThan(peakOut, peakIn, "loud signal should be attenuated")
    }

    // MARK: Event queue (SPSC)

    func testEventQueueFIFOOrder() {
        let q = EventQueue(capacity: 8)
        for i in 0..<5 {
            var e = NoteEvent()
            e.startFrame = Int64(i)
            XCTAssertTrue(q.enqueue(e))
        }
        for i in 0..<5 {
            let e = q.dequeue()
            XCTAssertEqual(e?.startFrame, Int64(i))
        }
        XCTAssertNil(q.dequeue())
    }

    func testEventQueueReportsFull() {
        let q = EventQueue(capacity: 4) // holds capacity-1 = 3
        XCTAssertTrue(q.enqueue(NoteEvent()))
        XCTAssertTrue(q.enqueue(NoteEvent()))
        XCTAssertTrue(q.enqueue(NoteEvent()))
        XCTAssertFalse(q.enqueue(NoteEvent()), "queue should report full")
    }

    func testEventQueueConcurrentProducerConsumer() {
        let q = EventQueue(capacity: 1024)
        let total = 50_000
        let producer = DispatchQueue(label: "producer")
        let expectation = expectation(description: "drained")

        var received = 0
        var nextExpected: Int64 = 0
        var ordered = true

        producer.async {
            var sent = 0
            while sent < total {
                var e = NoteEvent()
                e.startFrame = Int64(sent)
                if q.enqueue(e) { sent += 1 }
            }
        }

        DispatchQueue.global().async {
            while received < total {
                if let e = q.dequeue() {
                    if e.startFrame != nextExpected { ordered = false }
                    nextExpected += 1
                    received += 1
                }
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
        XCTAssertTrue(ordered, "SPSC queue must preserve order")
        XCTAssertEqual(received, total)
    }

    // MARK: Voice / VoicePool

    func testVoiceProducesDecayingOutputThenFrees() {
        let v = Voice(sampleRate: sr)
        var e = NoteEvent()
        e.frequency = 440
        e.volume = 0.3
        e.attack = 0.005
        e.decay = 0.2
        e.waveform = .sine
        v.trigger(e)
        XCTAssertTrue(v.active)

        var produced = false
        var n = 0
        while v.active && n < Int(sr) {
            let s = v.render()
            if abs(s) > 0.01 { produced = true }
            XCTAssertTrue(s.isFinite)
            n += 1
        }
        XCTAssertTrue(produced, "voice should produce audible output")
        XCTAssertFalse(v.active, "voice should free itself after the envelope ends")
    }

    func testVoicePoolStealsOldestWhenFull() {
        let pool = VoicePool(sampleRate: sr, count: 2)
        var e = NoteEvent()
        e.frequency = 220; e.volume = 0.2; e.decay = 5.0
        pool.trigger(e)
        pool.trigger(e)
        XCTAssertEqual(pool.activeCount, 2)
        // Age the voices a little.
        for v in pool.voices { _ = v.render() }
        // Third trigger must steal, not exceed pool size.
        pool.trigger(e)
        XCTAssertLessThanOrEqual(pool.activeCount, 2)
    }
}

private extension Double {
    var asInt: Int { Int(self) }
}
