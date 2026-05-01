//
//  HUDSettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import SwiftUI

struct HUD: View {
    @Environment(\.bindableSettings) var settings
    @Environment(\.xpcHelper) var xpcHelper
    @State private var accessibilityAuthorized = false
    
    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replace system HUD")
                            .font(.headline)
                        Text("Replaces the standard macOS volume, display brightness, and keyboard brightness HUDs with a custom design.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 40)
                    Toggle("", isOn: $settings.hudReplacement)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.large)
                    .disabled(!accessibilityAuthorized)
                }
                
                if !accessibilityAuthorized {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accessibility access is required to replace the system HUD.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button("Request Accessibility") {
                                xpcHelper?.requestAccessibilityAuthorization()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            
            Section {
                Picker("Option key behaviour", selection: $settings.optionKeyAction) {
                    ForEach(OptionKeyAction.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                
                Picker("Progress bar style", selection: $settings.enableGradient) {
                    Text("Hierarchical")
                        .tag(false)
                    Text("Gradient")
                        .tag(true)
                }
                Toggle(isOn: $settings.systemEventIndicatorShadow) {
                    Text("Enable glowing effect")
                }
                Toggle(isOn: $settings.systemEventIndicatorUseAccent) {
                    Text("Tint progress bar with accent color")
                }
            } header: {
                Text("General")
            }
            .disabled(!settings.hudReplacement)
            
            Section {
                Toggle(isOn: $settings.showOpenNotchHUD) {
                    Text("Show HUD in open notch")
                }
                Toggle(isOn: $settings.showOpenNotchHUDPercentage) {
                    Text("Show percentage")
                }
                .disabled(!settings.showOpenNotchHUD)
            } header: {
                HStack {
                    Text("Open Notch")
                    customBadge(text: "Beta")
                }
            }
            .disabled(!settings.hudReplacement)
            
            Section {
                Picker("HUD style", selection: $settings.inlineHUD) {
                    Text("Default")
                        .tag(false)
                    Text("Inline")
                        .tag(true)
                }
                .onChange(of: settings.inlineHUD) {
                    if settings.inlineHUD {
                        withAnimation {
                            settings.systemEventIndicatorShadow = false
                            settings.enableGradient = false
                        }
                    }
                }
                
                Toggle(isOn: $settings.showClosedNotchHUDPercentage) {
                    Text("Show percentage")
                }
            } header: {
                Text("Closed Notch")
            }
            .disabled(!settings.hudReplacement)
        }
        .accentColor(.effectiveAccent(from: settings))
        .navigationTitle("HUDs")
        .task {
            accessibilityAuthorized = await xpcHelper?.isAccessibilityAuthorized() ?? false
        }
        .onAppear {
            xpcHelper?.startMonitoringAccessibilityAuthorization()
        }
        .onDisappear {
            xpcHelper?.stopMonitoringAccessibilityAuthorization()
        }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityAuthorizationChanged)) { notification in
            if let granted = notification.userInfo?["granted"] as? Bool {
                accessibilityAuthorized = granted
            }
        }
    }
}
