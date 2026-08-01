//
//  SoundscapePlugin.swift
//  machNotch
//
//  Built-in generative soundscape plugin.
//  Uses MachSoundKit engine to generate adaptive ambient soundscapes.
//

import Combine
import CoreGraphics
import Defaults
import MachSoundKit
import NotchCore
import NotchServices
import NotchUI
import SwiftUI

@MainActor
@Observable
public final class SoundscapePlugin: NotchPlugin, PositionedPlugin {

    // MARK: - NotchPlugin Conformance

    public let id = PluginID.soundscape

    public let metadata = PluginMetadata(
        name: "Soundscape",
        description: "Adaptive, generative ambient soundscapes",
        icon: "waveform.path",
        version: "1.0.0",
        author: "machNotch",
        category: .media
    )

    public var isEnabled: Bool = true
    public private(set) var state: PluginState = .inactive

    // MARK: - PositionedPlugin Conformance

    public var closedNotchPosition: ClosedNotchPosition { .center }

    // MARK: - Observable States

    public var isPlaying: Bool = false
    public var currentMode: SoundMode = .edm
    public var volume: Double = 0.65
    public var isAdaptive: Bool = false

    public var energy: Double = 0.7
    public var pace: Double = 0.5
    public var density: Double = 0.5
    public var brightness: Double = 0.5
    public var space: Double = 0.5
    public var pulse: Double = 0.4
    public var texture: Double = 0.4

    // UI Reactivity
    public var audioLevel: Float = 0.0
    public var isBeatActive: Bool = false

    // MARK: - Internal Dependencies

    @ObservationIgnored var engine: SoundEngine?
    @ObservationIgnored var settings: PluginSettings?
    @ObservationIgnored var eventBus: PluginEventBus?
    @ObservationIgnored var cancellables = Set<AnyCancellable>()
    @ObservationIgnored var activeTasks: [Task<Void, Never>] = []

    // Cache to restore state after external media ducking
    @ObservationIgnored var wasPlayingBeforeDucking: Bool = false
    @ObservationIgnored var weatherService: (any WeatherServiceProtocol)?
    @ObservationIgnored var calendarService: (any CalendarServiceProtocol)?

    // Pomodoro tracking
    @ObservationIgnored var currentPomodoroPhase: PomodoroPhase = .none

    // MARK: - Initialization

    public init() {}

    // MARK: - Lifecycle

    public func activate(context: PluginContext) async throws {
        state = .activating

        self.settings = context.settings
        self.eventBus = context.eventBus
        self.weatherService = context.pluginExtensionServices.weather
        self.calendarService = context.pluginExtensionServices.calendar

        // Load settings
        loadSettings()

        // Initialize engine with initial context
        let initialContext = makeCurrentContext()
        let soundEngine = SoundEngine(context: initialContext)
        self.engine = soundEngine

        // Set engine properties
        soundEngine.setMode(currentMode)
        soundEngine.setVolume(volume)
        soundEngine.setEnergy(energy)
        soundEngine.setAdaptive(isAdaptive)
        soundEngine.setParameters(
            pace: pace,
            density: density,
            brightness: brightness,
            space: space,
            pulse: pulse,
            texture: texture
        )

        // Setup event bus subscriptions
        setupEventSubscriptions()

        // Setup system state observers (lock/unlock)
        setupSystemObservers()

        // Start task for beat events and level monitoring
        startBackgroundMonitoring(soundEngine)

        state = .active
    }

    public func deactivate() async {
        // Cancel all tasks and subscriptions
        cancellables.removeAll()
        activeTasks.forEach { $0.cancel() }
        activeTasks.removeAll()

        // Teardown engine
        engine?.pause()
        engine = nil

        settings = nil
        eventBus = nil
        weatherService = nil
        calendarService = nil

        state = .inactive
    }

    // MARK: - Public State Controllers

    public func togglePlay() {
        guard let engine = engine else { return }
        isPlaying.toggle()
        settings?.set("isPlaying", value: isPlaying)

        if isPlaying {
            // Check if system media is currently active (politeness rule)
            if isAdaptive && makeCurrentContext().mediaPlaying {
                // If media is playing, do not actually start audio, but keep playing intent active
                wasPlayingBeforeDucking = true
            } else {
                engine.play()
            }
        } else {
            engine.pause()
            wasPlayingBeforeDucking = false
        }
    }

    public func updateMode(_ mode: SoundMode) {
        currentMode = mode
        applyPrototypeDefaults(for: mode)
        engine?.setMode(mode)
        engine?.setParameters(
            pace: pace,
            density: density,
            brightness: brightness,
            space: space,
            pulse: pulse,
            texture: texture
        )
        settings?.set("mode", value: mode.rawValue)
    }

    public func updateVolume(_ val: Double) {
        volume = val
        engine?.setVolume(val)
        settings?.set("volume", value: val)
    }

    public func updateEnergy(_ val: Double) {
        energy = val
        engine?.setEnergy(val)
        settings?.set("energy", value: val)
    }

    public func updateAdaptive(_ enabled: Bool) {
        isAdaptive = enabled
        engine?.setAdaptive(enabled)
        settings?.set("isAdaptive", value: enabled)
        if enabled {
            updateContextState()
        }
    }

    public func updateParameter(_ key: String, value: Double) {
        switch key {
        case "pace": pace = value
        case "density": density = value
        case "brightness": brightness = value
        case "space": space = value
        case "pulse": pulse = value
        case "texture": texture = value
        default: break
        }
        settings?.set(key, value: value)
        engine?.setParameters(
            pace: pace,
            density: density,
            brightness: brightness,
            space: space,
            pulse: pulse,
            texture: texture
        )
    }

    // MARK: - UI Slots Conformance

    public var displayRequest: DisplayRequest? {
        guard isEnabled, state.isActive, isPlaying else { return nil }
        return DisplayRequest(priority: .high, category: DisplayRequest.music)
    }

    @ViewBuilder
    public func closedNotchContent() -> some View {
        if isEnabled, state.isActive {
            SoundscapeClosedView(plugin: self)
        }
    }

    @ViewBuilder
    public func expandedPanelContent() -> some View {
        if isEnabled, state.isActive {
            SoundscapeExpandedView(plugin: self)
        }
    }

    @ViewBuilder
    public func settingsContent() -> some View {
        SoundscapeSettingsContent(plugin: self)
    }

    @ViewBuilder
    public func menuBarView() -> some View {
        if isEnabled, state.isActive, isPlaying {
            Label("Soundscape: \(currentMode.rawValue.capitalized)", systemImage: "waveform.path")
        }
    }

    private func applyPrototypeDefaults(for mode: SoundMode) {
        guard let defaults = mode.prototypeSceneDefaults else { return }
        pace = defaults.pace
        density = defaults.density
        brightness = defaults.brightness
        space = defaults.space
        pulse = defaults.pulse
        texture = defaults.texture

        settings?.set("pace", value: pace)
        settings?.set("density", value: density)
        settings?.set("brightness", value: brightness)
        settings?.set("space", value: space)
        settings?.set("pulse", value: pulse)
        settings?.set("texture", value: texture)
    }
}
