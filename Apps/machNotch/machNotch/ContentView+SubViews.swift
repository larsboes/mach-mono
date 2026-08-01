//
//  ContentView+SubViews.swift
//  machNotch
//
//  Extracted from ContentView — background, overlay, and visualizer sub-views.
//

import SwiftUI

// MARK: - Extracted Sub-Views

extension ContentView {
    var visualizerActive: Bool {
        settings.ambientVisualizerEnabled
            && (musicService.playbackState.isPlaying || settings.visualizerShowWhenPaused)
            && vm.phase == .closed
    }

    @ViewBuilder
    var ambientVisualizerOverlay: some View {
        if visualizerActive {
            let totalHeight = displayClosedNotchHeight + settings.ambientVisualizerHeight
            let albumColor = Color(nsColor: musicService.avgColor).ensureMinimumBrightness(factor: 0.5)

            Color.black
                .frame(width: computedChinWidth, height: totalHeight)
                .overlay(alignment: .bottom) {
                    if let pluginManager {
                        pluginManager.ambientVisualizerView(
                            albumColor: albumColor,
                            isPlaying: true,
                            height: settings.ambientVisualizerHeight,
                            useRealAudio: settings.ambientVisualizerMode == .realAudio
                        )
                    } else {
                        Color.clear.frame(height: settings.ambientVisualizerHeight)
                    }
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 22,
                        bottomTrailingRadius: 22,
                        topTrailingRadius: 0
                    )
                )
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    var notchBackground: some View {
        ZStack {
            if settings.liquidGlassEffect {
                Rectangle()
                    .swiftGlassEffect(
                        isEnabled: true,
                        tintColor: musicService.playbackState.isPlaying
                            ? Color(nsColor: musicService.avgColor).opacity(0.3) : nil
                    )
            } else {
                Color.black
            }

            if vm.isHoveringNotch || vm.notchState == .open, let hoverImage = vm.backgroundImage {
                Image(nsImage: hoverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            }
        }
        .clipShape(currentNotchShape)
        .shadow(
            color: (animationProgress > 0.3 && settings.enableShadow)
                ? .black.opacity(0.7 * pow(animationProgress, 2.5)) : .clear, radius: 6
        )
    }

    @ViewBuilder
    var glassOverlay: some View {
        if settings.liquidGlassEffect {
            let borderMultiplier = lerp(0.6, 1.0, sqrt(animationProgress))
            currentNotchShape
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(settings.liquidGlassStyle.configuration.borderOpacity * borderMultiplier),
                            .white.opacity(
                                settings.liquidGlassStyle.configuration.borderOpacity * 0.3 * borderMultiplier),
                            .white.opacity(
                                settings.liquidGlassStyle.configuration.borderOpacity * 0.5 * borderMultiplier),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: settings.liquidGlassStyle.configuration.borderWidth
                )
        }
    }

    @ViewBuilder
    var topEdgeLine: some View {
        if !(displayClosedNotchHeight.isZero && vm.notchState == .closed) {
            Rectangle()
                .fill(settings.liquidGlassEffect ? .clear : .black)
                .frame(height: 1)
                .padding(.horizontal, topCornerRadius)
        }
    }
}
