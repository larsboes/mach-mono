//
//  HabitRow.swift
//  machNotch
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Active Habit Row

struct HabitRow: View {
    let habit: Habit
    let store: HabitStore
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var completionTrigger = false

    var body: some View {
        let isDone = store.isCompleted(habitId: habit.id)
        let stats = store.stats(for: habit.id)

        Button {
            let wasCompleted = store.isCompleted(habitId: habit.id)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                store.toggleCompletion(for: habit.id)
            }
            if !wasCompleted { completionTrigger.toggle() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isDone ? habit.color.opacity(0.22) : .white.opacity(0.07))
                        .frame(width: 34, height: 34)
                    Image(systemName: isDone ? "checkmark" : habit.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isDone ? habit.color : .white.opacity(0.72))
                    Circle()
                        .stroke(isDone ? habit.color.opacity(0.85) : .white.opacity(0.16), lineWidth: 1)
                        .frame(width: 34, height: 34)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isDone ? .white.opacity(0.58) : .white)
                        .strikethrough(isDone, color: .white.opacity(0.32))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if stats.totalCompletions > 0 {
                        HStack(spacing: 6) {
                            Label("\(stats.currentStreak)", systemImage: "flame.fill")
                                .labelStyle(.titleAndIcon)
                                .foregroundStyle(stats.currentStreak > 0 ? .orange : .white.opacity(0.38))
                            Text("\(Int(stats.completionRate30Days * 100))% 30d")
                                .foregroundStyle(.white.opacity(0.38))
                        }
                        .font(.system(size: 10, weight: .semibold))
                    }
                }

                Spacer()

                ZStack {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isDone ? habit.color : .white.opacity(0.22))
                        .opacity(isHovered ? 0 : 1)

                    if isHovered {
                        Menu {
                            Button("Edit") { onEdit() }
                            Button("Disable") {
                                var updated = habit
                                updated.isActive = false
                                store.updateHabit(updated)
                            }
                            Divider()
                            Button("Delete", role: .destructive) { onDelete() }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.65))
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(.white.opacity(0.1)))
                        }
                        .menuStyle(.automatic)
                    }
                }
                .frame(width: 24, height: 24)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .sensoryFeedback(.success, trigger: completionTrigger)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? .white.opacity(0.105) : .white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isDone ? habit.color.opacity(0.28) : .white.opacity(0.06), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Inactive Habit Row

struct InactiveHabitRow: View {
    let habit: Habit
    let store: HabitStore
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(.white.opacity(0.04)).frame(width: 34, height: 34)
                Image(systemName: habit.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.28))
                Circle().stroke(.white.opacity(0.08), lineWidth: 1).frame(width: 34, height: 34)
            }

            Text(habit.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            HStack(spacing: 6) {
                Button { onDelete() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.55))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(.red.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .contentShape(Circle())

                Button {
                    var updated = habit
                    updated.isActive = true
                    store.updateHabit(updated)
                } label: {
                    Text("Resume")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Drop Delegate

@MainActor
struct HabitDropDelegate: DropDelegate {
    let targetId: UUID
    let store: HabitStore
    @Binding var draggingId: UUID?

    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingId, dragging != targetId,
              let from = store.habits.firstIndex(where: { $0.id == dragging }),
              let to = store.habits.firstIndex(where: { $0.id == targetId })
        else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            store.reorderHabits(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
