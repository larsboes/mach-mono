//
//  MediaSettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import SwiftUI

struct Media: View {
    @Environment(\.bindableSettings) var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker("Music Source", selection: $settings.mediaController) {
                    ForEach(availableMediaControllers) { controller in
                        Text(controller.rawValue).tag(controller)
                    }
                }
                .onChange(of: settings.mediaController) { _, _ in
                    NotificationCenter.default.post(
                        name: Notification.Name.mediaControllerChanged,
                        object: nil
                    )
                }
            } header: {
                Text("Media Source")
            } footer: {
                if settings.isNowPlayingDeprecated {
                    HStack {
                        Text("YouTube Music requires this third-party app to be installed: ")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Link(
                            "https://github.com/pear-devs/pear-desktop",
                            destination: URL(string: "https://github.com/pear-devs/pear-desktop")!
                        )
                        .font(.caption)
                        .foregroundColor(.blue)  // Ensures it's visibly a link
                    }
                } else {
                    Text(
                        "'Now Playing' was the only option on previous versions and works with all media apps."
                    )
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }
            
            Section {
                Toggle(
                    "Show music live activity",
                    isOn: $settings.musicLiveActivityEnabled.animation()
                )
                Toggle(
                    "Ambient visualizer glow",
                    isOn: $settings.ambientVisualizerEnabled.animation()
                )
                if settings.ambientVisualizerEnabled {
                    Picker("Visualizer mode", selection: $settings.ambientVisualizerMode) {
                        ForEach(AmbientVisualizerMode.allCases) { mode in
                            Label(mode.displayName, systemImage: mode.icon).tag(mode)
                        }
                    }
                    HStack {
                        Text("Visualizer height")
                        Spacer()
                        Text("\(Int(settings.ambientVisualizerHeight))px")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.ambientVisualizerHeight, in: 80...220, step: 10)
                    HStack {
                        Text("Sensitivity")
                        Spacer()
                        Text(String(format: "%.0f%%", settings.visualizerSensitivity * 100))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.visualizerSensitivity, in: 0...1, step: 0.05)
                    if settings.ambientVisualizerMode == .realAudio {
                        Picker("Band count", selection: $settings.visualizerBandCount) {
                            ForEach(VisualizerBandCount.allCases) { count in
                                Text(count.displayName).tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    Toggle("Show when paused", isOn: $settings.visualizerShowWhenPaused)
                }
                Toggle("Show sneak peek on playback changes", isOn: $settings.enableSneakPeek)
                Picker("Sneak Peek Style", selection: $settings.sneakPeekStyles) {
                    ForEach(SneakPeekStyle.selectableCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                HStack {
                    Stepper(value: $settings.waitInterval, in: 0...10, step: 1) {
                        HStack {
                            Text("Media inactivity timeout")
                            Spacer()
                            Text("\(settings.waitInterval, specifier: "%.0f") seconds")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Picker(
                    selection: $settings.hideNotchOption,
                    label:
                        HStack {
                            Text("Full screen behavior")
                            customBadge(text: "Beta")
                        }
                ) {
                    Text("Hide for all apps").tag(HideNotchOption.always)
                    Text("Hide for media app only").tag(
                        HideNotchOption.nowPlayingOnly)
                    Text("Never hide").tag(HideNotchOption.never)
                }
            } header: {
                Text("Media playback live activity")
            }
            
            Section {
                MusicSlotConfigurationView()
                Toggle(isOn: $settings.enableLyrics) {
                    HStack {
                        Text("Show lyrics below artist name")
                        customBadge(text: "Beta")
                    }
                }
            } header: {
                Text("Media controls")
            }  footer: {
                Text("Customize which controls appear in the music player. Volume expands when active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent(from: settings))
        .navigationTitle("Media")
    }

    // Only show controller options that are available on this macOS version
    private var availableMediaControllers: [MediaControllerType] {
        if settings.isNowPlayingDeprecated {
            return MediaControllerType.allCases.filter { $0 != .nowPlaying }
        } else {
            return MediaControllerType.allCases
        }
    }
}
