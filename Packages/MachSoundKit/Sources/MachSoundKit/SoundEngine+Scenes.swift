import Foundation
import MachSoundDSP

extension SoundEngine {

    // MARK: - Scenes (Focus / Relax / Sleep) — random chord walk, never loops
    func executeSceneStep(_ s: Int, frame f: Int64, mode: SoundMode, parameters: SoundEngineParameters) {
        let dens = max(0.0, min(1.0, parameters.density * (0.5 + energy)))
        let bright = parameters.brightness
        let pulse = parameters.pulse
        let pace = parameters.pace
        let spb = 60.0 / getBPM(parameters: parameters)

        if s % 32 == 0 {
            triggerSceneChordWalk(step: s)
            let chord = currentSceneChord

            let cutoff = 350 + 2200 * bright
            let attack = 1.0 + 2.5 * (1.0 - pace)
            triggerPads(frame: f, midiNotes: chord.map { $0 + 12 }, volume: 0.05,
                        attack: attack, release: 3.0, cutoff: cutoff, dur: spb * 8 + 2,
                        beatRoot: chord[0])

            let peak = 0.10 + 0.10 * (1.0 - bright)
            triggerSubSwell(frame: f, rootMidi: Double(chord[0] - 12), peakVol: peak,
                            attack: 2.5, hold: 0, release: max(0.5, spb * 8 + 1.5 - 2.5),
                            beat: (.bass, Int32(chord[0])))
        }

        // Thump (kick)
        if s % 8 == 0 && pulse > 0.1 {
            triggerKick(frame: f, freqStart: 65 + 50 * pulse, freqEnd: 36,
                        duration: 0.45 + 0.5 * (1.0 - pace), volume: 0.14 + 0.34 * pulse,
                        beat: (.kick, -1))
        }

        // Pluck
        if s % 2 == 0 && Double.random(in: 0...1) < dens * 0.5 {
            let oct = Double.random(in: 0...1) < 0.45 ? 24.0 : 12.0
            let note = Double(currentSceneChord.randomElement() ?? 60) + oct
            triggerPluck(frame: f, midi: note, volume: 0.028 + 0.05 * dens,
                         duration: 0.7 + 1.6 * (1.0 - pace),
                         waveform: Double.random(in: 0...1) < 0.5 ? .sine : .triangle,
                         sendRev: true, beat: (.note, Int32(note)))
        }

        // Shimmer
        if s % 16 == 8 && Double.random(in: 0...1) < 0.18 * bright {
            let note = currentSceneChord[0] + 36
            triggerPluck(frame: f, midi: Double(note), volume: 0.018, duration: 2.2,
                         waveform: .sine, sendRev: true, beat: (.note, Int32(note)))
        }
    }

    func triggerSceneChordWalk(step: Int) {
        let scale: [Int]
        let root: Int
        switch currentMode {
        case .focus:
            root = 48 // C3
            scale = [0, 2, 4, 7, 9]  // major pentatonic
        case .relax:
            root = 45 // A2
            scale = [0, 3, 5, 7, 10] // minor pentatonic
        case .sleep:
            root = 38 // D2
            scale = [0, 3, 7, 10]    // sparse minor
        default:
            root = 48
            scale = [0, 2, 4, 7, 9]
        }

        if step > 0 {
            let delta = [-2, -1, 1, 2].randomElement() ?? 1
            sceneDegree = positiveModulo(sceneDegree + delta + scale.count * 8, scale.count)
        }

        func midiNote(degree: Int) -> Int {
            let len = scale.count
            let idx = positiveModulo(degree, len)
            let octave = degree / len
            return root + scale[idx] + octave * 12
        }

        currentSceneChord = [
            midiNote(degree: sceneDegree),
            midiNote(degree: sceneDegree + 2),
            midiNote(degree: sceneDegree + 4)
        ]
    }

    private func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
        let r = value % modulus
        return r >= 0 ? r : r + modulus
    }
}
