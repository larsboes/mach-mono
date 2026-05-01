//
//  NotchMoodView.swift
//  boringNotch
//
//  Created by Alexander on 2025-12-29.
//

import SwiftUI

struct NotchMoodView: View {
    @Environment(\.settings) var settings
    @Environment(\.pluginManager) var pluginManager
    
    // Fallback if pluginManager is nil (shouldn't happen in production)
    var faceService: any FaceServiceProtocol {
        pluginManager?.services.face ?? FaceService(settings: settings)
    }
    
    @State private var blink = false
    @State private var breathe = false
    
    var spacing: CGFloat = 8
    
    var body: some View {
        let currentMood = faceService.isSleepy ? .sleepy : settings.selectedMood
        let isSplit = spacing > 20
        
        ZStack {
            // Eyes
            HStack(spacing: spacing) {
                EyeView(mood: currentMood, blink: blink)
                    .offset(faceService.eyeOffset)
                EyeView(mood: currentMood, blink: blink)
                    .offset(faceService.eyeOffset)
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
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Blinking
        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                blink = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    blink = false
                }
            }
        }
        
        // Breathing
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            breathe = true
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
