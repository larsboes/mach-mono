//
//  MarqueeTextView.swift
//  NotchUI
//

import SwiftUI

struct SizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct MeasureSizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geometry in
                Color.clear.preference(key: SizePreferenceKey.self, value: geometry.size)
            })
    }
}

public struct MarqueeText: View {
    /// Gap between the text and its trailing copy. Also the distance the copy
    /// sits ahead of the original, so it doubles as part of the scroll length.
    private static let gap: CGFloat = 20
    /// Scroll speed. Constant regardless of title length, so a long track name
    /// does not race past.
    private static let pointsPerSecond: CGFloat = 30

    let text: String
    let font: Font
    let nsFont: NSFont.TextStyle
    let color: Color
    let delayDuration: Double
    let frameWidth: CGFloat

    @Environment(\.isDisplayActive) private var isDisplayActive

    @State private var animate = false
    @State private var textWidth: CGFloat = 0

    public init(
        _ text: String, font: Font = .body, nsFont: NSFont.TextStyle = .body, color: Color = .primary,
        delayDuration: Double = 3.0, frameWidth: CGFloat
    ) {
        self.text = text
        self.font = font
        self.nsFont = nsFont
        self.color = color
        self.delayDuration = delayDuration
        self.frameWidth = frameWidth
    }

    private var needsScrolling: Bool {
        textWidth > frameWidth
    }

    /// One full cycle moves the original off the left edge and lands its copy
    /// exactly where the original started.
    private var scrollDistance: CGFloat {
        textWidth + Self.gap
    }

    private var lineHeight: CGFloat {
        NSFont.preferredFont(forTextStyle: nsFont).pointSize
    }

    /// A scrolling title is a perpetual animation, so it stands down with the
    /// display rather than running against a dark screen.
    private var isScrolling: Bool {
        animate && isDisplayActive
    }

    public var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .leading) {
                HStack(spacing: Self.gap) {
                    Text(text)
                    Text(text)
                        .opacity(needsScrolling ? 1 : 0)
                }
                .id(text)
                .font(font)
                .foregroundColor(color)
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: isScrolling ? -scrollDistance : 0)
                .animation(
                    isScrolling
                        ? .linear(duration: Double(scrollDistance / Self.pointsPerSecond))
                            .delay(delayDuration)
                            .repeatForever(autoreverses: false) : nil,
                    value: isScrolling
                )
                .modifier(MeasureSizeModifier())
                .onPreferenceChange(SizePreferenceKey.self) { size in
                    // The HStack measures both copies plus the gap.
                    textWidth = max(0, (size.width - Self.gap) / 2)
                }
            }
            .frame(width: frameWidth, alignment: .leading)
            .clipped()
        }
        .frame(height: lineHeight * 1.3)
        // Restarting through `task(id:)` rather than from the preference
        // callback means a title change cancels the in-flight restart instead of
        // racing it. The yield still has to be a real frame: SwiftUI must commit
        // the reset to offset 0 before the repeating animation is attached.
        .task(id: restartKey) {
            animate = false
            guard needsScrolling, isDisplayActive else { return }
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }
            animate = true
        }
    }

    private var restartKey: [String] {
        [text, "\(frameWidth)", "\(needsScrolling)", "\(isDisplayActive)"]
    }
}
