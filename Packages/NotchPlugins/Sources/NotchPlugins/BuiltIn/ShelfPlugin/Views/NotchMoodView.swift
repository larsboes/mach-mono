//
//  NotchMoodView.swift
//  machNotch
//
//  Created by Alexander on 2025-12-29.
//

import SwiftUI

public struct NotchMoodView: View {
    @Environment(\.settings) var settings
    @Environment(\.pluginManager) var pluginManager

    /// Nil only when the view is hosted without a plugin manager, such as in a
    /// preview. Never falls back to a fresh `FaceService`: constructing one
    /// inside a computed property installs a pointer monitor per view
    /// evaluation, and nothing ever removes it.
    private var faceService: (any FaceServiceProtocol)? {
        pluginManager?.services.face
    }

    @State private var blink = false
    @State private var breathe = false

    public var spacing: CGFloat = 8

    public init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    public var body: some View {
        let face = faceService
        let currentMood = (face?.isSleepy ?? false) ? .sleepy : settings.selectedMood
        let eyeOffset = face?.eyeOffset ?? .zero
        let isSplit = spacing > 20

        ZStack {
            // Eyes
            HStack(spacing: spacing) {
                EyeView(mood: currentMood, blink: blink)
                    .offset(eyeOffset)
                EyeView(mood: currentMood, blink: blink)
                    .offset(eyeOffset)
            }
            .offset(y: breathe ? -1 : 0)

            // Mouth (only show if not split)
            if !isSplit {
                MouthView(mood: currentMood)
                    .offset(y: 8 + (breathe ? 0.5 : 0))
            }

            // Eyebrows
            HStack(spacing: isSplit ? spacing + 4 : 12) {
                EyebrowView(mood: currentMood)
                EyebrowView(mood: currentMood)
            }
            .offset(y: -8 + (breathe ? -0.5 : 0))
        }
        .onAppear {
            // Pointer tracking runs only while a face is on screen.
            faceService?.startMonitoring()
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .onDisappear {
            faceService?.stopMonitoring()
        }
        .task {
            // `.task` is cancelled when the view goes away. The previous version
            // scheduled an unowned repeating Timer in `onAppear`, so every
            // appearance left another one firing for the life of the app.
            await blinkForever()
        }
    }

    private func blinkForever() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.1)) { blink = true }
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeInOut(duration: 0.1)) { blink = false }
        }
    }
}

struct EyeView: View {
    let mood: Mood
    let blink: Bool

    var body: some View {
        Capsule()
            .fill(Color.white)
            .frame(width: 4, height: blink ? 1 : height)
            .animation(.spring(), value: blink)
    }

    private var height: CGFloat {
        switch mood {
        case .sleepy: return 1
        case .surprised: return 6
        default: return 4
        }
    }
}

struct MouthView: View {
    let mood: Mood

    var body: some View {
        Group {
            if mood == .surprised {
                Circle()
                    .stroke(Color.white, lineWidth: 1.5)
                    .frame(width: 6, height: 6)
            } else if mood == .angry {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 8, height: 1.5)
            } else {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addQuadCurve(to: CGPoint(x: 10, y: 0), control: CGPoint(x: 5, y: controlY))
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 10, height: 5)
            }
        }
    }

    private var controlY: CGFloat {
        switch mood {
        case .happy: return 4
        case .sad: return -4
        default: return 0
        }
    }
}

struct EyebrowView: View {
    let mood: Mood

    var body: some View {
        if mood == .angry || mood == .sad || mood == .surprised {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 6, y: yOffset))
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .frame(width: 6, height: 2)
        } else {
            EmptyView()
        }
    }

    private var yOffset: CGFloat {
        switch mood {
        case .angry: return 2
        case .sad: return -2
        case .surprised: return -1
        default: return 0
        }
    }
}
