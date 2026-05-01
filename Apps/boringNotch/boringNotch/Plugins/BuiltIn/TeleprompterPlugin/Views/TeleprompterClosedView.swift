import SwiftUI

/// Closed-notch teleprompter display — the primary reading view.
/// The notch extends well below camera level, giving a generous reading area
/// right below the camera for natural eye contact.
struct TeleprompterClosedView: View {
    let state: TeleprompterState

    @Environment(BoringViewModel.self) var vm
    @Environment(\.displayClosedNotchHeight) var displayClosedNotchHeight

    /// Real notch height (camera area) — keep text out of this zone
    private var cameraZoneHeight: CGFloat {
        getRealNotchHeight()
    }

    /// The reading area below the camera
    private var readingAreaHeight: CGFloat {
        max(0, displayClosedNotchHeight - cameraZoneHeight)
    }

    /// Match closed notch width + flanking (same pattern as MusicLiveActivity)
    private var contentWidth: CGFloat {
        vm.closedNotchSize.width + 100
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top zone — physical notch area (camera lives here, stay clear)
            Color.clear
                .frame(height: cameraZoneHeight)

            // Reading zone — teleprompter text, directly below camera
            ZStack {
                // Background Voice Glow Beam (Only active while scrolling/playing AND not transitioning)
                if state.isScrolling, !vm.phase.isTransitioning {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.8),
                                    Color.indigo.opacity(0.6),
                                    Color.purple.opacity(0.4),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        // Scale the height based on vocal input
                        .frame(height: max(10, readingAreaHeight * state.micMonitor.normalizedLevel))
                        // Fade in on voice, but keep a dim glow otherwise
                        .opacity(0.2 + (state.micMonitor.normalizedLevel * 0.8))
                        // Aggressive blurred blend for glass aesthetic
                        .blur(radius: 12)
                        .blendMode(.screen)
                        // Top aligned so it beams out directly from beneath the notch
                        .frame(maxHeight: .infinity, alignment: .top)
                        .animation(.interpolatingSpring(stiffness: 120, damping: 14), value: state.micMonitor.normalizedLevel)
                }

                if state.text.isEmpty {
                    Text("No script loaded")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                } else {
                    ScrollView {
                        Text(state.text)
                            .font(.system(
                                size: state.config.fontSize,
                                weight: .medium,
                                design: .default
                            ))
                            .foregroundStyle(state.textColor.color.opacity(0.95))
                            .lineSpacing(8)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: contentWidth - 32)
                            .padding(.top, 8)
                            .padding(.bottom, readingAreaHeight)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(key: TeleprompterContentHeightKey.self, value: geo.size.height)
                                }
                            )
                            .offset(y: -state.scrollPosition)
                    }
                    .scrollDisabled(true)
                    .scrollIndicators(.never)
                    // Karaoke fade — top lines bright, fading down
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: 0.35),
                                .init(color: .white.opacity(0.5), location: 0.65),
                                .init(color: .clear, location: 0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .onHover { hovering in
                        state.isHovering = hovering
                    }
                    .onPreferenceChange(TeleprompterContentHeightKey.self) { height in
                        if abs(state.contentHeight - Double(height)) > 1.0 {
                            Task { @MainActor in
                                state.contentHeight = Double(height)
                            }
                        }
                    }
                }
            }
            .frame(width: contentWidth, height: readingAreaHeight)
            .clipped()
            .overlay(alignment: .bottom) {
                if !state.text.isEmpty {
                    readingChrome
                }
            }
        }
        .frame(width: contentWidth, height: displayClosedNotchHeight)
        .overlay {
            if state.countdownState.isActive {
                CountdownOverlayView(state: state.countdownState)
            }
        }
        .onDisappear {
            state.timerManager.micMonitor.stopMonitoring()
        }
        .onChange(of: vm.notchState) {
            if vm.notchState != .closed {
                state.timerManager.micMonitor.stopMonitoring()
            }
        }
    }

    // MARK: - Reading Chrome

    /// Progress bar, section title, speed slider, stop button, and elapsed/remaining time.
    private var readingChrome: some View {
        VStack(spacing: 4) {
            Spacer()

            // Speed slider row
            HStack(spacing: 6) {
                Image(systemName: "tortoise")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.3))

                Slider(
                    value: Binding(
                        get: { state.config.speed },
                        set: { state.config.speed = $0 }
                    ),
                    in: 10...150,
                    step: 5
                )
                .tint(.white.opacity(0.4))
                .controlSize(.mini)

                Image(systemName: "hare")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.3))

                Text("\(Int(state.config.speed))")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 24, alignment: .trailing)
            }
            .padding(.horizontal, 12)

            // Bottom row: elapsed time, section, close button, remaining time
            HStack(spacing: 6) {
                if state.isScrolling || state.scrollPosition > 0 {
                    Text(state.elapsedTimeString)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                }

                if let section = state.currentSectionTitle {
                    Text(section)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                }

                Spacer()

                // Stop / close button — prominent
                Button {
                    state.reset()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if state.isScrolling || state.scrollPosition > 0 {
                    Text(state.remainingTimeString)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            // Progress bar
            GeometryReader { geo in
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(height: 2)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(.white.opacity(0.5))
                            .frame(width: geo.size.width * state.progress)
                    }
            }
            .frame(height: 2)
        }
    }
}

// MARK: - Preference Key

struct TeleprompterContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
