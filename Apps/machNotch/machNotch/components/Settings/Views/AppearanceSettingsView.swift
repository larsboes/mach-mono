//
//  AppearanceSettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import AVFoundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct Appearance: View {
    @Environment(\.bindableSettings) var settings

    let icons: [String] = ["logo2"]
    @State private var selectedIcon: String = "logo2"
    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Toggle("Always show tabs", isOn: $settings.alwaysShowTabs)
                Toggle(isOn: $settings.settingsIconInNotch) {
                    Text("Show settings icon in notch")
                }

            } header: {
                Text("General")
            }

            Section {
                Toggle(isOn: $settings.coloredSpectrogram) {
                    Text("Colored spectrogram")
                }
                Toggle("Player tinting", isOn: $settings.playerColorTinting)
                Toggle(isOn: $settings.lightingEffect) {
                    Text("Enable blur effect behind album art")
                }
                Picker("Slider color", selection: $settings.sliderColor) {
                    ForEach(SliderColorEnum.allCases, id: \.self) { option in
                        Text(option.rawValue)
                    }
                }
            } header: {
                Text("Media")
            }

            Section {
                Toggle(isOn: $settings.liquidGlassEffect) {
                    HStack {
                        Text("Liquid Glass Effect")
                        Text("Beta")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                if settings.liquidGlassEffect {
                    Picker("Glass Style", selection: $settings.liquidGlassStyle) {
                        ForEach(LiquidGlassStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    
                    // SwiftGlass configuration
                    LabeledContent {
                        Slider(value: $settings.liquidGlassBlurRadius, in: 5...50, step: 5)
                        .frame(width: 150)
                    } label: {
                        Text("Blur Intensity")
                    }
                }
                Toggle(isOn: $settings.enableShadow) {
                    Text("Enable shadow")
                }
            } header: {
                Text("Glass Effect")
            }
            
            Section {
                ZStack {
                    if let imageURL = settings.backgroundImageURL,
                       let nsImage = NSImage(contentsOf: imageURL) {
                        ZStack(alignment: .topTrailing) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Button {
                                if let imageURL = settings.backgroundImageURL {
                                    try? FileManager.default.removeItem(at: imageURL)
                                }
                                settings.backgroundImageURL = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                            .offset(x: 6, y: -6)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 24))
                            )
                    }
                }
                .frame(width: 80, height: 80)
                .contentShape(Rectangle())
                .onTapGesture {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowedContentTypes = [.image]
                    panel.message = "Select Background Image"
                    
                    if panel.runModal() == .OK, let sourceURL = panel.url {
                        if let copiedURL = BoringViewModel.copyBackgroundImageToAppStorage(sourceURL: sourceURL) {
                            settings.backgroundImageURL = copiedURL
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Notch Background")
            }

            Section {
                Toggle(isOn: $settings.showMirror) {
                    Text("Enable boring mirror")
                }
                    .disabled(!checkVideoInput())
                Picker("Mirror shape", selection: $settings.mirrorShape) {
                    Text("Circle")
                        .tag(MirrorShapeEnum.circle)
                    Text("Square")
                        .tag(MirrorShapeEnum.rectangle)
                }
                Toggle(isOn: $settings.showNotHumanFace) {
                    Text("Show cool face animation while inactive")
                }
            } header: {
                HStack {
                    Text("Additional features")
                }
            }
        }
        .accentColor(.effectiveAccent(from: settings))
        .navigationTitle("Appearance")
    }

    func checkVideoInput() -> Bool {
        if AVCaptureDevice.default(for: .video) != nil {
            return true
        }

        return false
    }
}
