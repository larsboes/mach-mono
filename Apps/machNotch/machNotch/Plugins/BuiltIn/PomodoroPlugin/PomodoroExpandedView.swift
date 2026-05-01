//
//  PomodoroExpandedView.swift
//  boringNotch
//

import SwiftUI

struct PomodoroExpandedView: View {
    let plugin: PomodoroPlugin
    @Environment(BoringViewCoordinator.self) var coordinator
    private var timer: PomodoroTimer { plugin.timer }
    
    var body: some View {
        HStack(spacing: 20) {
            // Timer ring (compact)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 5)
                
                Circle()
                    .trim(from: 0, to: CGFloat(timer.progress))
                    .stroke(timer.currentType.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: timer.progress)
                
                VStack(spacing: 2) {
                    Text(timer.timeRemainingString)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    
                    Text(timer.currentType.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(timer.currentType.color)
                }
            }
            .frame(width: 80, height: 80)
            
            // Right side: session dots + controls
            VStack(spacing: 10) {
                // Session dots
                HStack(spacing: 4) {
                    ForEach(0..<timer.settings.sessionsUntilLongBreak, id: \.self) { i in
                        Circle()
                            .fill(i < timer.completedWorkSessions ? Color.red : Color.white.opacity(0.2))
                            .frame(width: 5, height: 5)
                    }
                }
                
                // Controls
                HStack(spacing: 12) {
                    Button(action: { timer.reset() }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if timer.isRunning { timer.stop() } else { timer.start() }
                    }) {
                        Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(timer.currentType.color)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { timer.skip() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
