import AVFoundation
import Foundation
import MachSoundDSP

/// Generative soundscape engine.
///
/// The DSP is a custom sample-accurate core (`SynthCore`) rendered through a
/// single `AVAudioSourceNode`. A lookahead scheduler (`SoundEngine+Controls`)
/// runs on a timer, computes the musical steps for each generator
/// (`SoundEngine+Generators` / `SoundEngine+Scenes`), and enqueues
/// frame-stamped `NoteEvent`s into a lock-free queue the render thread drains.
///
/// `@unchecked Sendable`: cross-thread state is guarded by `stateLock`; audio
/// data crosses to the render thread only through the lock-free `EventQueue`
/// and `BeatSink`.
public final class SoundEngine: @unchecked Sendable {
    // MARK: Audio
    let avEngine = AVAudioEngine()
    var sourceNode: AVAudioSourceNode?
    let sampleRate: Double
    let synthCore: SynthCore
    let eventQueue = EventQueue(capacity: 4096)
    let beatSink = BeatSink(capacity: 1024)

    let stateLock = NSLock()

    // MARK: State
    var isPlaying = false
    var currentMode: SoundMode = .edm
    var context: SoundContext

    // Sound parameters (0–1)
    var pace: Double = 0.5
    var density: Double = 0.5
    var brightness: Double = 0.5
    var space: Double = 0.5
    var pulse: Double = 0.5
    var texture: Double = 0.5
    var energy: Double = 0.7
    var volume: Double = 0.65
    var isAdaptive: Bool = false
    var effectiveParameters = SoundEngineParameters.defaults

    // MARK: Scheduler (frame-based)
    let schedulerQueue = DispatchQueue(label: "com.machnotch.soundscape.scheduler", qos: .userInteractive)
    var schedulerTimer: DispatchSourceTimer?
    var nextStepFrame: Int64 = 0
    var lastScheduledStep: Int = -1
    var schedulerStarted = false

    // MARK: Visuals beat stream
    var beatContinuation: AsyncStream<BeatEvent>.Continuation?
    public lazy var beatEvents: AsyncStream<BeatEvent> = {
        AsyncStream { continuation in
            self.stateLock.lock()
            self.beatContinuation = continuation
            self.stateLock.unlock()
        }
    }()

    public var audioLevel: Float { synthCore.audioLevel }

    // MARK: Scene state (scheduler-thread)
    var sceneDegree = 0
    var currentSceneChord: [Int] = [48, 51, 55] // Cm root

    // MARK: - Initializer
    public init(context: SoundContext) {
        self.context = context
        let outFormat = avEngine.outputNode.outputFormat(forBus: 0)
        let sr = outFormat.sampleRate > 0 ? outFormat.sampleRate : 48000
        self.sampleRate = sr
        self.synthCore = SynthCore(sampleRate: sr, eventQueue: eventQueue, beatSink: beatSink)
        setupAudioGraph(sampleRate: sr)
        setupRoutingNotification()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopScheduler()
        avEngine.stop()
    }

    // MARK: - Audio graph
    private func setupAudioGraph(sampleRate: Double) {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
            ?? AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        let core = synthCore
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, ablPtr in
            core.render(frameCount: Int(frameCount), bufferList: ablPtr)
            return noErr
        }
        sourceNode = node
        avEngine.attach(node)
        avEngine.connect(node, to: avEngine.mainMixerNode, format: format)
        avEngine.prepare()
    }

    private func setupRoutingNotification() {
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: avEngine,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            self.stateLock.lock()
            let playing = self.isPlaying
            self.stateLock.unlock()
            guard playing else { return }
            do {
                self.avEngine.prepare()
                try self.avEngine.start()
            } catch {
                print("machSound engine restart after route change failed: \(error)")
            }
        }
    }

    // MARK: - Play / Pause API
    public func play() {
        stateLock.lock()
        guard !isPlaying else { stateLock.unlock(); return }
        let mode = currentMode
        let params = effectiveParameters
        nextStepFrame = 0
        lastScheduledStep = -1
        schedulerStarted = false
        stateLock.unlock()

        synthCore.reset()
        synthCore.updateControls(currentControls(parameters: params, mode: mode))

        do {
            try avEngine.start()
            stateLock.lock()
            isPlaying = true
            stateLock.unlock()
            startScheduler()
            print("machSound Engine started.")
        } catch {
            print("machSound Engine start failed: \(error)")
        }
    }

    public func pause() {
        stateLock.lock()
        guard isPlaying else { stateLock.unlock(); return }
        isPlaying = false
        stateLock.unlock()

        stopScheduler()
        avEngine.stop()
        print("machSound Engine paused.")
    }
}
