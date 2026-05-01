//
//  HabitClosedView.swift
//  boringNotch
//

import SwiftUI

struct HabitClosedView: View {
    let plugin: HabitTrackerPlugin
    
    // Only fetch for UI updates without modifying directly here
    private var store: HabitStore { plugin.store }
    
    var body: some View {
        HStack(spacing: 4) {
            let activeHabits = store.habits.filter { $0.isActive }
            
            if activeHabits.isEmpty {
                 Image(systemName: "checkmark.circle")
                     .font(.system(size: 14, weight: .medium))
                     .foregroundColor(.white.opacity(0.5))
            } else {
                ForEach(activeHabits.prefix(5)) { habit in
                    let isDone = store.isCompleted(habitId: habit.id)
                    Circle()
                        .fill(isDone ? habit.color : .white.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
                
                if activeHabits.count > 5 {
                    Text("+\(activeHabits.count - 5)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.leading, 2)
                }
            }
        }
        .padding(.horizontal, 6)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.completions)
    }
}
