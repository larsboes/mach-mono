//
//  HabitExpandedView.swift
//  boringNotch
//

import SwiftUI

struct HabitExpandedView: View {
    @Environment(BoringViewCoordinator.self) var coordinator
    let plugin: HabitTrackerPlugin
    private var store: HabitStore { plugin.store }
    
    @State private var hoveredHabitId: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Habit Tracker")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 4)
                .padding(.top, 4)
            
            let activeHabits = store.habits.filter { $0.isActive }
            
            if activeHabits.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No active habits")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Add some in settings")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(activeHabits) { habit in
                            HabitRow(habit: habit, store: store, isHovered: hoveredHabitId == habit.id)
                                .onHover { hovering in
                                    hoveredHabitId = hovering ? habit.id : nil
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .onAppear {
            coordinator.isScrollableViewPresented = true
        }
        .onDisappear {
            coordinator.isScrollableViewPresented = false
        }
    }
}

private struct HabitRow: View {
    let habit: Habit
    let store: HabitStore
    let isHovered: Bool
    
    var body: some View {
        let isDone = store.isCompleted(habitId: habit.id)
        let stats = store.stats(for: habit.id)
        
        HStack(spacing: 12) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    store.toggleCompletion(for: habit.id)
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(isDone ? habit.color : .white.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isDone {
                        Circle()
                            .fill(habit.color)
                            .frame(width: 16, height: 16)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDone ? .white.opacity(0.6) : .white)
                    .strikethrough(isDone, color: .white.opacity(0.4))
                
                HStack(spacing: 6) {
                    Image(systemName: habit.symbol)
                        .font(.system(size: 10))
                        .foregroundColor(habit.color.opacity(0.8))
                    
                    if stats.currentStreak > 0 {
                        Text("\(stats.currentStreak) \u{1F525}") // Fire emoji
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                    } else {
                        Text("\(Int(stats.completionRate30Days * 100))%")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovered ? .white.opacity(0.1) : .white.opacity(0.05))
        )
    }
}
