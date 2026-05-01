//
//  NotchVolumeControl.swift
//  boringNotch
//
//  Created by Refactoring Agent on 2025-12-30.
//

import SwiftUI

struct VolumeControlView: View {
    @Environment(\.pluginManager) var pluginManager
    @State private var volumeSliderValue: Double = 0.5
    @State private var dragging: Bool = false
    @State private var showVolumeSlider: Bool = false
    @State private var lastVolumeUpdateTime: Date = Date.distantPast
    private let volumeUpdateThrottle: TimeInterval = 0.1
    
    var body: some View {
        Group {
            if let service = pluginManager?.services.music {
                HStack(spacing: 4) {
                    Button(action: {
                        if service.volumeControlSupported {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                showVolumeSlider.toggle()
                            }
                        }
                    }) {
                        Image(systemName: volumeIcon(service: service))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(service.volumeControlSupported ? .white : .gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!service.volumeControlSupported)
                    .frame(width: 24)

                    if showVolumeSlider && service.volumeControlSupported {
                        CustomSlider(
                            value: $volumeSliderValue,
                            range: 0.0...1.0,
                            color: .white,
                            dragging: $dragging,
                            lastDragged: .constant(Date.distantPast),
                            onValueChange: { newValue in
                                Task { await service.setVolume(newValue) }
                            },
                            onDragChange: { newValue in
                                let now = Date()
                                if now.timeIntervalSince(lastVolumeUpdateTime) > volumeUpdateThrottle {
                                    Task { await service.setVolume(newValue) }
                                    lastVolumeUpdateTime = now
                                }
                            }
                        )
                        .frame(width: 48, height: 8)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .clipped()
                .onChange(of: service.volume) { _, volume in
                    if !dragging {
                        volumeSliderValue = volume
                    }
                }
                .onChange(of: service.volumeControlSupported) { _, supported in
                    if !supported {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showVolumeSlider = false
                        }
                    }
                }
                .onChange(of: showVolumeSlider) { _, isShowing in
                    if isShowing {
                        Task {
                            await service.syncVolumeFromActiveApp()
                        }
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
    
    private func volumeIcon(service: any MusicServiceProtocol) -> String {
        if !service.volumeControlSupported {
            return "speaker.slash"
        } else if volumeSliderValue == 0 {
            return "speaker.slash.fill"
        } else if volumeSliderValue < 0.33 {
            return "speaker.1.fill"
        } else if volumeSliderValue < 0.66 {
            return "speaker.2.fill"
        } else {
            return "speaker.3.fill"
        }
    }
}
