import AVFoundation
import Foundation
import MachSoundDSP

extension SoundEngine {

    // MARK: - Parameters API
    public func setMode(_ mode: SoundMode) {
        stateLock.lock()
        self.currentMode = mode
        if mode == .focus || mode == .relax || mode == .sleep {
            sceneDegree = 0
        }
        stateLock.unlock()

        // Seed the scene chord so the first scheduled step has a chord to voice.
        if mode == .focus || mode == .relax || mode == .sleep {
            triggerSceneChordWalk(step: 0)
        }
    }

    public func setParameters(
        pace: Double,
        density: Double,
        brightness: Double,
        space: Double,
        pulse: Double,
        texture: Double
    ) {
        stateLock.lock()
        defer { stateLock.unlock() }
        self.pace = pace
        self.density = density
        self.brightness = brightness
        self.space = space
        self.pulse = pulse
        self.texture = texture
    }

    public func setEnergy(_ energy: Double) {
        stateLock.lock()
        defer { stateLock.unlock() }
        self.energy = energy
    }

    public func setVolume(_ volume: Double) {
        stateLock.lock()
        defer { stateLock.unlock() }
        self.volume = volume
    }

    public func setAdaptive(_ enabled: Bool) {
        stateLock.lock()
        defer { stateLock.unlock() }
        self.isAdaptive = enabled
    }

    public func updateContext(_ newContext: SoundContext) {
        stateLock.lock()
        defer { stateLock.unlock() }
        self.context = newContext
    }

    // MARK: - Lookahead Scheduler
    func startScheduler() {
        stopScheduler()
        let timer = DispatchSource.makeTimerSource(queue: schedulerQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(25))
        timer.setEventHandler { [weak self] in self?.schedulerTick() }
        timer.resume()
        self.schedulerTimer = timer
    }

    func stopScheduler() {
        schedulerTimer?.cancel()
        schedulerTimer = nil
    }

    private func schedulerTick() {
        stateLock.lock()
        guard isPlaying else { stateLock.unlock(); return }

        let mode = currentMode
        let now = synthCore.currentFrame
        let elapsed = Double(now) / sampleRate

        updateDrift(elapsed: elapsed)
        let params = effectiveParameters
        let controls = currentControls(parameters: params, mode: mode)

        let bpm = getBPM(parameters: params)
        let stepFrames = max(Int64(1), Int64(60.0 / bpm / 4.0 * sampleRate))

        if !schedulerStarted {
            nextStepFrame = now + Int64(0.12 * sampleRate)
            lastScheduledStep = -1
            schedulerStarted = true
        }

        let lookahead = now + Int64(0.20 * sampleRate)
        var steps: [(Int, Int64)] = []
        while nextStepFrame < lookahead {
            let step = lastScheduledStep + 1
            steps.append((step, nextStepFrame))
            lastScheduledStep = step
            nextStepFrame += stepFrames
        }
        stateLock.unlock()

        synthCore.updateControls(controls)

        for (step, frame) in steps {
            executeStep(step, frame: frame, mode: mode, parameters: params)
        }

        drainBeats()
    }

    func getBPM(parameters: SoundEngineParameters? = nil) -> Double {
        let paceValue = parameters?.pace ?? pace
        switch currentMode {
        case .edm: return 126.0
        case .ambient: return 72.0
        case .lofi: return 78.0
        case .focus: return 96.0 * (0.75 + 0.5 * paceValue)
        case .relax: return 66.0 * (0.75 + 0.5 * paceValue)
        case .sleep: return 52.0 * (0.75 + 0.5 * paceValue)
        }
    }

    // MARK: - Continuous control plane (computed each tick, smoothed on render thread)
    func currentControls(parameters: SoundEngineParameters, mode: SoundMode) -> SynthControls {
        var c = SynthControls()
        c.masterGain = volume * volume

        let spb = 60.0 / getBPM(parameters: parameters)
        c.delaySamples = max(1, Int(spb * 0.75 * sampleRate))
        c.delayFeedback = 0.32

        switch mode {
        case .edm:
            c.reverbReturnGain = 0.16
            c.reverbRoom = 0.78
            c.reverbDamping = 0.48
        case .ambient:
            c.reverbReturnGain = 0.55
            c.reverbRoom = 0.94
            c.reverbDamping = 0.28
        case .lofi:
            c.reverbReturnGain = 0.22
            c.reverbRoom = 0.82
            c.reverbDamping = 0.42
        case .focus, .relax, .sleep:
            c.reverbReturnGain = 0.1 + 0.6 * parameters.space
            c.reverbRoom = 0.90
            c.reverbDamping = 0.32
        }

        c.vinylGain = (mode == .lofi) ? 0.012 : 0.0

        if mode == .focus || mode == .relax || mode == .sleep {
            c.textureGain = 0.012 + 0.022 * parameters.texture
            c.textureCutoff = 250.0 + 2800.0 * parameters.brightness
        } else {
            c.textureGain = 0.0
            c.textureCutoff = 900.0
        }
        return c
    }

    // MARK: - Parameter drift (v2-style slow LFO wander)
    private func updateDrift(elapsed: TimeInterval) {
        let activityBias = isAdaptive ? (context.activity - 0.3) * 0.18 : 0.0
        let effectivePace = driftedValue(base: pace + activityBias, frequency: 0.0035, phase: 0.0, time: elapsed)
        let effectiveDensity = driftedValue(base: density + activityBias, frequency: 0.0061, phase: 2.1, time: elapsed)
        let effectiveBrightness = driftedValue(base: brightness, frequency: 0.0047, phase: 4.2, time: elapsed)
        let effectiveSpace = driftedValue(base: space, frequency: 0.0028, phase: 1.3, time: elapsed)
        let effectivePulse = driftedValue(base: pulse + activityBias, frequency: 0.0072, phase: 3.4, time: elapsed)
        let effectiveTexture = driftedValue(base: texture, frequency: 0.0041, phase: 5.5, time: elapsed)
        effectiveParameters = SoundEngineParameters(
            pace: effectivePace,
            density: effectiveDensity,
            brightness: effectiveBrightness,
            space: effectiveSpace,
            pulse: effectivePulse,
            texture: effectiveTexture
        )
    }

    private func driftedValue(base: Double, frequency: Double, phase: Double, time: Double) -> Double {
        let drift = 0.08 * sin(2.0 * .pi * frequency * time + phase)
        return max(0.0, min(1.0, base + drift))
    }

    // MARK: - Visual beat drain (off the render thread)
    func drainBeats() {
        stateLock.lock()
        let continuation = beatContinuation
        stateLock.unlock()
        guard let continuation else { return }
        while let r = beatSink.pop() {
            switch r.kind {
            case .kick: continuation.yield(.kick)
            case .bass: continuation.yield(.bass(midi: Int(r.midi)))
            case .chord: continuation.yield(.chord(rootMidi: Int(r.midi)))
            case .note: continuation.yield(.note(midi: Int(r.midi)))
            case .none: break
            }
        }
    }
}
