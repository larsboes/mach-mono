import Foundation
import MachSoundDSP

extension SoundEngine {

    // MARK: - Step dispatch
    func executeStep(_ step: Int, frame: Int64, mode: SoundMode, parameters: SoundEngineParameters) {
        switch mode {
        case .edm:    executeEdmStep(step, frame: frame)
        case .ambient: executeAmbientStep(step, frame: frame)
        case .lofi:   executeLofiStep(step, frame: frame)
        case .focus, .relax, .sleep:
            executeSceneStep(step, frame: frame, mode: mode, parameters: parameters)
        }
    }

    // MARK: - EDM (Classical × EDM, 126 BPM, C minor, Beethoven-5 motif)
    private func executeEdmStep(_ s: Int, frame f: Int64) {
        let bar = s / 16
        let sb = s % 16
        let sec = (bar / 8) % 4
        let secMult = [0.6, 0.85, 1.0, 0.55][sec]
        let e = energy * secMult

        let chords = [[48, 51, 55], [44, 48, 51], [46, 50, 53], [43, 47, 50]] // Cm Ab Bb G
        let roots: [Double] = [36, 32, 34, 31]
        let ch = chords[bar % 4]
        let root = roots[bar % 4]

        let spb = 60.0 / getBPM()
        let st = spb / 4.0

        // Pad (1 bar)
        if sb == 0 {
            triggerPads(frame: f, midiNotes: ch, volume: 0.05, attack: 0.08, release: 0.6,
                        cutoff: 1100 + 600 * e, dur: spb * 4, beatRoot: ch[0])
        }

        // Drums
        if s % 4 == 0 && e >= 0.28 {
            triggerKick(frame: f, freqStart: 150, freqEnd: 44, duration: 0.30, volume: 0.95,
                        triggersDuck: true, beat: (.kick, -1))
        }
        if s % 4 == 2 && e >= 0.48 {
            triggerNoiseHit(frame: f, filter: .highpass, freq: 7500, q: 1, volume: 0.16, duration: 0.05,
                            beat: (.note, 72))
        }
        if (sb == 4 || sb == 12) && e >= 0.62 {
            triggerNoiseHit(frame: f, filter: .bandpass, freq: 1800, q: 1.2, volume: 0.4, duration: 0.13)
        }
        if sec == 3 && bar % 8 == 7 {
            triggerNoiseHit(frame: f, filter: .bandpass, freq: 1900, q: 1.5,
                            volume: 0.12 + 0.02 * Double(sb), duration: 0.08)
        }

        // Bass
        if s % 2 == 0 && e >= 0.42 {
            let vol = (s % 4 == 0) ? 0.30 : 0.22
            triggerBass(frame: f, midi: root, volume: vol, duration: st * 2 * 0.9,
                        beat: (.bass, Int32(root)))
        }

        // Lead motif
        if e >= 0.38 {
            let motif: [Int: (Int, Int)] = [
                2: (67, 6), 4: (67, 2), 6: (67, 2), 8: (63, 8),
                18: (65, 6), 20: (65, 2), 22: (65, 2), 24: (62, 8)
            ]
            if let hit = motif[s % 32] {
                let dur = st * Double(hit.1) * 0.95
                triggerLead(frame: f, midi: Double(hit.0), volume: 0.16, duration: dur,
                            beat: (.note, Int32(hit.0)))
                if e >= 0.85 {
                    triggerLead(frame: f, midi: Double(hit.0 + 12), volume: 0.07, duration: dur)
                }
            }
        }

        // Arp plucks (dry square)
        if e >= 0.78 {
            let tones = [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[1] + 24]
            triggerPluck(frame: f, midi: Double(tones[s % 4]), volume: 0.07, duration: 0.14,
                         waveform: .square, sendRev: false)
        }
    }

    // MARK: - Ambient (72 BPM, A minor)
    private func executeAmbientStep(_ s: Int, frame f: Int64) {
        let chords = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]] // Am F C G
        let roots: [Double] = [45, 41, 36, 43]
        let idx = (s / 32) % 4
        let ch = chords[idx]
        let root = roots[idx]
        let e = energy
        let spb = 60.0 / getBPM()

        if s % 32 == 0 {
            triggerPads(frame: f, midiNotes: ch, volume: 0.055, attack: 2.0, release: 3.0,
                        cutoff: 750 + 500 * e, dur: spb * 8 + 1, beatRoot: ch[0])
            triggerSubSwell(frame: f, rootMidi: root - 12, peakVol: 0.16 * e + 0.04,
                            attack: 2.5, hold: 0, release: max(0.5, spb * 8 - 2.5))
        }

        if s % 64 == 16 && e >= 0.35 {
            triggerKick(frame: f, freqStart: 90, freqEnd: 32, duration: 1.1, volume: 0.5,
                        beat: (.kick, -1))
        }

        if s % 2 == 0 && Double.random(in: 0...1) < 0.30 + 0.45 * e {
            let oct = Double.random(in: 0...1) < 0.4 ? 24 : 12
            let note = (ch.randomElement() ?? 60) + oct
            triggerPluck(frame: f, midi: Double(note), volume: 0.05 + 0.05 * e, duration: 0.9,
                         waveform: Double.random(in: 0...1) < 0.5 ? .sine : .triangle,
                         sendRev: true, beat: (.note, Int32(note)))
        }

        if s % 16 == 8 && Double.random(in: 0...1) < 0.3 * e {
            let note = ch[0] + 36
            triggerPluck(frame: f, midi: Double(note), volume: 0.025, duration: 1.6,
                         waveform: .sine, sendRev: true, beat: (.note, Int32(note)))
        }
    }

    // MARK: - Lo-Fi (78 BPM, jazzy 7ths, swung offbeats)
    private func executeLofiStep(_ s: Int, frame f: Int64) {
        let bar = s / 16
        let sb = s % 16
        let chords = [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59]]
        let roots: [Double] = [41, 40, 38, 36]
        let penta = [72, 74, 76, 79, 81]
        let ch = chords[bar % 4]
        let root = roots[bar % 4]
        let e = energy
        let spb = 60.0 / getBPM()

        // Swung offbeat 8ths.
        let swing = (s % 4 == 2) ? spb * 0.14 : 0.0
        let base = frame(f, plus: swing)

        if sb == 0 || sb == 10 {
            triggerRhodesChord(frame: base, midiNotes: ch, volume: 0.055, duration: 1.6, beatRoot: ch[0])
        }
        if (sb == 0 || sb == 7) && e >= 0.3 {
            triggerKick(frame: base, freqStart: 95, freqEnd: 42, duration: 0.22, volume: 0.5,
                        beat: (.kick, -1))
        }
        if (sb == 4 || sb == 12) && e >= 0.3 {
            triggerNoiseHit(frame: base, filter: .lowpass, freq: 3800, q: 0.8, volume: 0.18, duration: 0.16,
                            beat: (.bass, 50))
        }
        if s % 4 == 2 && e >= 0.55 {
            triggerNoiseHit(frame: base, filter: .highpass, freq: 8200, q: 1, volume: 0.05, duration: 0.04)
        }
        if (sb == 0 || sb == 8) && e >= 0.35 {
            triggerBass(frame: base, midi: root - 12, volume: 0.20, duration: 0.5)
        }
        if s % 4 == 0 && Double.random(in: 0...1) < 0.22 + 0.3 * e {
            let note = penta.randomElement() ?? 72
            triggerRhodesNote(frame: frame(f, plus: swing + 0.02), midi: Double(note),
                              volume: 0.05, duration: 1.1, beat: (.note, Int32(note)))
        }
        if Double.random(in: 0...1) < 0.045 {
            triggerNoiseHit(frame: base, filter: .bandpass, freq: 3000, q: 8, volume: 0.04, duration: 0.015)
        }
    }
}
