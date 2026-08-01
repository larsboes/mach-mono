//
//  HabitClosedView.swift
//  machNotch
//

import SwiftUI

struct HabitClosedView: View {
    let plugin: HabitTrackerPlugin
    private var store: HabitStore { plugin.store }

    var body: some View {
        let activeHabits = store.habits.filter(\.isActive)
        let completedCount = activeHabits.filter { store.isCompleted(habitId: $0.id) }.count
        let progress = activeHabits.isEmpty ? 0.0 : Double(completedCount) / Double(activeHabits.count)

        Group {
            if activeHabits.isEmpty {
                EmptyView()
            } else if activeHabits.count <= 5 {
                HStack(spacing: 5) {
                    ForEach(activeHabits) { habit in
                        let isDone = store.isCompleted(habitId: habit.id)
                        ZStack {
                            Circle()
                                .fill(isDone ? habit.color : .clear)
                                .frame(width: 8, height: 8)
                            Circle()
                                .stroke(isDone ? habit.color : .white.opacity(0.35), lineWidth: 1.5)
                                .frame(width: 8, height: 8)
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDone)
                    }
                }
                .padding(.horizontal, 4)
            } else {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 2)
                            .frame(width: 14, height: 14)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 14, height: 14)
                            .rotationEffect(.degrees(-90))
                            .animation(.smooth(duration: 0.25), value: progress)
                        if progress >= 1 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.green)
                        }
                    }
                    Text("\(completedCount)/\(activeHabits.count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(progress >= 1 ? .green : .white.opacity(0.72))
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 4)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.completions)
    }
}
