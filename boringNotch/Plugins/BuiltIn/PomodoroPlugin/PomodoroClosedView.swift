//
//  PomodoroClosedView.swift
//  boringNotch
//

import SwiftUI

struct PomodoroClosedView: View {
    let plugin: PomodoroPlugin
    private var timer: PomodoroTimer { plugin.timer }
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 14, height: 14)
                
                if timer.isRunning || timer.timeRemaining < timer.settings.workDuration {
                    Circle()
                        .trim(from: 0, to: CGFloat(timer.progress))
                        .stroke(timer.currentType.color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 14, height: 14)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: timer.progress)
                }
            }
            
            if timer.isRunning {
                Text(timer.timeRemainingString)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(timer.currentType.color)
                    .contentTransition(.numericText())
            } else if timer.timeRemaining < timer.settings.workDuration && timer.progress > 0 {
                // Paused but started
                Image(systemName: "pause.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 4)
    }
}
