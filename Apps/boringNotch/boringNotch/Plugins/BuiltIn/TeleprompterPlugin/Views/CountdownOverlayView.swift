import SwiftUI

/// Full-screen countdown overlay that displays a ticking number with scale/opacity animations.
///
/// The overlay is only visible while `state.isActive` is `true`.
/// Tapping anywhere cancels the countdown.
///
/// ```swift
/// CountdownOverlayView(state: countdownState)
/// ```
struct CountdownOverlayView: View {

    @Bindable var state: CountdownState

    var body: some View {
        if state.isActive {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.6)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // Countdown number — keyed by value so SwiftUI treats each tick as a new view.
                    Text("\(state.countdownValue)")
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .id(state.countdownValue)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: state.countdownValue)

                    Spacer()

                    // Cancel hint
                    Text("Tap to cancel")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 24)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                state.cancel()
            }
        }
    }
}
