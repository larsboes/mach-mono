//
//  DefaultsNotchSettings+Music.swift
//  boringNotch
//

import Foundation
import Defaults

@MainActor extension DefaultsNotchSettings {
    // MARK: - Music & Media Settings
    var isNowPlayingDeprecated: Bool {
        get { Defaults[.isNowPlayingDeprecated] }
        set { Defaults[.isNowPlayingDeprecated] = newValue }
    }
    var musicLiveActivityEnabled: Bool {
        get { Defaults[.musicLiveActivityEnabled] }
        set { Defaults[.musicLiveActivityEnabled] = newValue }
    }
    var enableSneakPeek: Bool {
        get { Defaults[.enableSneakPeek] }
        set { Defaults[.enableSneakPeek] = newValue }
    }
    var sneakPeekStyles: SneakPeekStyle {
        get { Defaults[.sneakPeekStyles] }
        set { Defaults[.sneakPeekStyles] = newValue }
    }
    var sneakPeakDuration: Double {
        get { Defaults[.sneakPeakDuration] }
        set { Defaults[.sneakPeakDuration] = newValue }
    }
    var coloredSpectrogram: Bool {
        get { Defaults[.coloredSpectrogram] }
        set { Defaults[.coloredSpectrogram] = newValue }
    }
    var playerColorTinting: Bool {
        get { Defaults[.playerColorTinting] }
        set { Defaults[.playerColorTinting] = newValue }
    }
    var sliderColor: SliderColorEnum {
        get { Defaults[.sliderColor] }
        set { Defaults[.sliderColor] = newValue }
    }
    var enableLyrics: Bool {
        get { Defaults[.enableLyrics] }
        set { Defaults[.enableLyrics] = newValue }
    }
    var selectedMood: Mood {
        get { Defaults[.selectedMood] }
        set { Defaults[.selectedMood] = newValue }
    }
    var waitInterval: Double {
        get { Defaults[.waitInterval] }
        set { Defaults[.waitInterval] = newValue }
    }
    var hideNotchOption: HideNotchOption {
        get { Defaults[.hideNotchOption] }
        set { Defaults[.hideNotchOption] = newValue }
    }
    var mediaController: MediaControllerType {
        get { Defaults[.mediaController] }
        set { Defaults[.mediaController] = newValue }
    }
    var mirrorShape: MirrorShapeEnum {
        get { Defaults[.mirrorShape] }
        set { Defaults[.mirrorShape] = newValue }
    }
    var musicControlSlots: [MusicControlButton] {
        get { Defaults[.musicControlSlots] }
        set { Defaults[.musicControlSlots] = newValue }
    }
    var selectedVisualizerURL: URL? {
        get { Defaults[.selectedVisualizerURL] }
        set { Defaults[.selectedVisualizerURL] = newValue }
    }
    var selectedVisualizerSpeed: Double {
        get { Defaults[.selectedVisualizerSpeed] }
        set { Defaults[.selectedVisualizerSpeed] = newValue }
    }
    var ambientVisualizerEnabled: Bool {
        get { Defaults[.ambientVisualizerEnabled] }
        set { Defaults[.ambientVisualizerEnabled] = newValue }
    }
    var ambientVisualizerHeight: CGFloat {
        get { Defaults[.ambientVisualizerHeight] }
        set { Defaults[.ambientVisualizerHeight] = newValue }
    }
    var ambientVisualizerMode: AmbientVisualizerMode {
        get { Defaults[.ambientVisualizerMode] }
        set { Defaults[.ambientVisualizerMode] = newValue }
    }
    var visualizerSensitivity: Double {
        get { Defaults[.visualizerSensitivity] }
        set { Defaults[.visualizerSensitivity] = newValue }
    }
    var visualizerShowWhenPaused: Bool {
        get { Defaults[.visualizerShowWhenPaused] }
        set { Defaults[.visualizerShowWhenPaused] = newValue }
    }
    var visualizerBandCount: VisualizerBandCount {
        get { Defaults[.visualizerBandCount] }
        set { Defaults[.visualizerBandCount] = newValue }
    }
}
