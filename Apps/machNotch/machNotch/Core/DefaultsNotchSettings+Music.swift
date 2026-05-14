//
//  DefaultsNotchSettings+Music.swift
//  machNotch
//
//  Music playback, visualizer, lyrics, sneak peek, and media controller settings.
//

import Defaults
import NotchSettingsMacro
import SwiftUI

extension DefaultsNotchSettings {

    // MARK: - Playback

    @Setting<Bool>(key: "musicLiveActivityEnabled", default: true)
    var musicLiveActivityEnabled: Bool {
        get { Defaults[Self.musicLiveActivityEnabledKey] }
        set { Defaults[Self.musicLiveActivityEnabledKey] = newValue }
    }

    @Setting<SliderColorEnum>(key: "sliderUseAlbumArtColor", default: SliderColorEnum.white)
    var sliderColor: SliderColorEnum {
        get { Defaults[Self.sliderColorKey] }
        set { Defaults[Self.sliderColorKey] = newValue }
    }

    @Setting<Bool>(key: "playerColorTinting", default: true)
    var playerColorTinting: Bool {
        get { Defaults[Self.playerColorTintingKey] }
        set { Defaults[Self.playerColorTintingKey] = newValue }
    }

    @Setting<Bool>(key: "showShuffleAndRepeat", default: false)
    var showShuffleAndRepeat: Bool {
        get { Defaults[Self.showShuffleAndRepeatKey] }
        set { Defaults[Self.showShuffleAndRepeatKey] = newValue }
    }

    @Setting<Bool>(key: "enableLyrics", default: false)
    var enableLyrics: Bool {
        get { Defaults[Self.enableLyricsKey] }
        set { Defaults[Self.enableLyricsKey] = newValue }
    }

    @Setting<[MusicControlButton]>(key: "musicControlSlots", default: MusicControlButton.defaultLayout)
    var musicControlSlots: [MusicControlButton] {
        get { Defaults[Self.musicControlSlotsKey] }
        set { Defaults[Self.musicControlSlotsKey] = newValue }
    }

    @Setting<Int>(key: "musicControlSlotLimit", default: MusicControlButton.defaultLayout.count)
    var musicControlSlotLimit: Int {
        get { Defaults[Self.musicControlSlotLimitKey] }
        set { Defaults[Self.musicControlSlotLimitKey] = newValue }
    }

    // Cannot use @Setting — default depends on another Defaults key (circular macro expansion).
    private static let mediaControllerKey = Defaults.Key<MediaControllerType>("mediaController", default: .nowPlaying)
    var mediaController: MediaControllerType {
        get { Defaults[Self.mediaControllerKey] }
        set { Defaults[Self.mediaControllerKey] = newValue }
    }

    // MARK: - Visualizer

    @Setting<Bool>(key: "coloredSpectrogram", default: true)
    var coloredSpectrogram: Bool {
        get { Defaults[Self.coloredSpectrogramKey] }
        set { Defaults[Self.coloredSpectrogramKey] = newValue }
    }

    @Setting<URL?>(key: "selectedVisualizerURL", default: nil)
    var selectedVisualizerURL: URL? {
        get { Defaults[Self.selectedVisualizerURLKey] }
        set { Defaults[Self.selectedVisualizerURLKey] = newValue }
    }

    @Setting<Double>(key: "selectedVisualizerSpeed", default: 1.0)
    var selectedVisualizerSpeed: Double {
        get { Defaults[Self.selectedVisualizerSpeedKey] }
        set { Defaults[Self.selectedVisualizerSpeedKey] = newValue }
    }

    @Setting<Bool>(key: "ambientVisualizerEnabled", default: false)
    var ambientVisualizerEnabled: Bool {
        get { Defaults[Self.ambientVisualizerEnabledKey] }
        set { Defaults[Self.ambientVisualizerEnabledKey] = newValue }
    }

    @Setting<CGFloat>(key: "ambientVisualizerHeight", default: 110)
    var ambientVisualizerHeight: CGFloat {
        get { Defaults[Self.ambientVisualizerHeightKey] }
        set { Defaults[Self.ambientVisualizerHeightKey] = newValue }
    }

    @Setting<AmbientVisualizerMode>(key: "ambientVisualizerMode", default: .simulated)
    var ambientVisualizerMode: AmbientVisualizerMode {
        get { Defaults[Self.ambientVisualizerModeKey] }
        set { Defaults[Self.ambientVisualizerModeKey] = newValue }
    }

    @Setting<Double>(key: "visualizerSensitivity", default: 0.5)
    var visualizerSensitivity: Double {
        get { Defaults[Self.visualizerSensitivityKey] }
        set { Defaults[Self.visualizerSensitivityKey] = newValue }
    }

    @Setting<Bool>(key: "visualizerShowWhenPaused", default: false)
    var visualizerShowWhenPaused: Bool {
        get { Defaults[Self.visualizerShowWhenPausedKey] }
        set { Defaults[Self.visualizerShowWhenPausedKey] = newValue }
    }

    @Setting<VisualizerBandCount>(key: "visualizerBandCount", default: .thirtyTwo)
    var visualizerBandCount: VisualizerBandCount {
        get { Defaults[Self.visualizerBandCountKey] }
        set { Defaults[Self.visualizerBandCountKey] = newValue }
    }

    // MARK: - Sneak Peek

    @Setting<Bool>(key: "enableSneakPeek", default: false)
    var enableSneakPeek: Bool {
        get { Defaults[Self.enableSneakPeekKey] }
        set { Defaults[Self.enableSneakPeekKey] = newValue }
    }

    @Setting<SneakPeekStyle>(key: "sneakPeekStyles", default: .standard)
    var sneakPeekStyles: SneakPeekStyle {
        get { Defaults[Self.sneakPeekStylesKey] }
        set { Defaults[Self.sneakPeekStylesKey] = newValue }
    }

    @Setting<Double>(key: "sneakPeakDuration", default: 1.5)
    var sneakPeakDuration: Double {
        get { Defaults[Self.sneakPeakDurationKey] }
        set { Defaults[Self.sneakPeakDurationKey] = newValue }
    }

    @Setting<Mood>(key: "selectedMood", default: .neutral)
    var selectedMood: Mood {
        get { Defaults[Self.selectedMoodKey] }
        set { Defaults[Self.selectedMoodKey] = newValue }
    }

    @Setting<Double>(key: "waitInterval", default: 3)
    var waitInterval: Double {
        get { Defaults[Self.waitIntervalKey] }
        set { Defaults[Self.waitIntervalKey] = newValue }
    }
}
