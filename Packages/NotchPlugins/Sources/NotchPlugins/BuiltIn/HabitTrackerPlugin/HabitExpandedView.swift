//
//  HabitExpandedView.swift
//  machNotch
//

import SwiftUI
import UniformTypeIdentifiers

struct HabitExpandedView: View {
    let plugin: HabitTrackerPlugin
    private var store: HabitStore { plugin.store }

    @State private var showingAddForm = false
    @State private var editingHabit: Habit? = nil
    @State private var habitToDelete: Habit? = nil
    @State private var showingInactive = false
    @State private var celebrationPulse = false
    @State private var draggingHabitId: UUID? = nil

    private var activeHabits: [Habit] { store.habits.filter(\.isActive) }
    private var inactiveHabits: [Habit] { store.habits.filter { !$0.isActive } }
    private var completedCount: Int { activeHabits.filter { store.isCompleted(habitId: $0.id) }.count }
    private var progress: Double { activeHabits.isEmpty ? 0 : Double(completedCount) / Double(activeHabits.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // True empty: no habits at all → suggestion chips
            if store.habits.isEmpty && !showingAddForm && editingHabit == nil {
                emptyState
            } else {
                HabitSummaryHeader(
                    completedCount: completedCount,
                    totalCount: activeHabits.count,
                    progress: progress,
                    celebrationPulse: celebrationPulse,
                    showingAddForm: $showingAddForm,
                    editingHabit: $editingHabit
                )

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        if showingAddForm {
                            HabitFormView(store: store, existingHabit: nil) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showingAddForm = false }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        } else if let habit = editingHabit {
                            HabitFormView(store: store, existingHabit: habit) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { editingHabit = nil }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        ForEach(activeHabits) { habit in
                            HabitRow(habit: habit, store: store) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    editingHabit = habit
                                    showingAddForm = false
                                }
                            } onDelete: {
                                habitToDelete = habit
                            }
                            .opacity(draggingHabitId == habit.id ? 0.4 : 1.0)
                            .onDrag {
                                draggingHabitId = habit.id
                                return NSItemProvider(object: habit.id.uuidString as NSString)
                            }
                            .onDrop(
                                of: [UTType.plainText],
                                delegate: HabitDropDelegate(
                                    targetId: habit.id,
                                    store: store,
                                    draggingId: $draggingHabitId
                                ))
                        }

                        if !inactiveHabits.isEmpty { inactiveSection }
                    }
                    .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingAddForm)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: editingHabit?.id)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingInactive)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: store.habits.isEmpty)
        .onChange(of: progress) { old, new in
            guard old < 1.0 && new >= 1.0 && !activeHabits.isEmpty else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { celebrationPulse = true }
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.easeOut(duration: 0.4)) { celebrationPulse = false }
            }
        }
        .alert(item: $habitToDelete) { habit in
            Alert(
                title: Text("Delete \"\(habit.title)\"?"),
                message: Text("This permanently removes the habit and its entire history."),
                primaryButton: .destructive(Text("Delete")) { store.deleteHabit(id: habit.id) },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: - Empty State (truly no habits)

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))

            Text("Start your habit stack")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))

            HStack(spacing: 8) {
                ForEach(HabitSuggestion.defaults, id: \.title) { s in
                    Button {
                        store.addHabit(Habit(title: s.title, symbol: s.symbol, colorHex: s.color.hexFormat))
                    } label: {
                        Label(s.title, systemImage: s.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(s.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(s.color.opacity(0.12)))
                            .overlay(Capsule().stroke(s.color.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                }
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showingAddForm = true }
            } label: {
                Label("Custom", systemImage: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.07)))
            }
            .buttonStyle(.plain)
            .contentShape(Capsule())
        }
        .frame(maxWidth: .infinity, minHeight: 126)
    }

    // MARK: - Inactive Section

    private var inactiveSection: some View {
        VStack(spacing: 6) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showingInactive.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text("\(inactiveHabits.count) paused")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                    Image(systemName: showingInactive ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.28))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            if showingInactive {
                ForEach(inactiveHabits) { habit in
                    InactiveHabitRow(habit: habit, store: store) { habitToDelete = habit }
                }
            }
        }
    }
}

// MARK: - Suggestion data

private struct HabitSuggestion {
    let title: String
    let symbol: String
    let color: Color

    static let defaults: [HabitSuggestion] = [
        HabitSuggestion(title: "Exercise", symbol: "figure.walk", color: .orange),
        HabitSuggestion(title: "Read", symbol: "book.fill", color: .purple),
        HabitSuggestion(title: "Drink Water", symbol: "drop.fill", color: .blue),
    ]
}

// MARK: - Summary Header

private struct HabitSummaryHeader: View {
    let completedCount: Int
    let totalCount: Int
    let progress: Double
    let celebrationPulse: Bool
    @Binding var showingAddForm: Bool
    @Binding var editingHabit: Habit?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.28), value: progress)
                Text(totalCount == 0 ? "—" : "\(Int(progress * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .frame(width: 58, height: 58)
            .scaleEffect(celebrationPulse ? 1.10 : 1.0)
            .shadow(color: celebrationPulse ? .green.opacity(0.7) : .clear, radius: celebrationPulse ? 10 : 0)

            VStack(alignment: .leading, spacing: 5) {
                Text("Today")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(totalCount == 0 ? "All habits paused" : "\(completedCount) of \(totalCount) complete")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .contentTransition(.numericText())
                HabitProgressBar(progress: progress)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    editingHabit = nil
                    showingAddForm.toggle()
                }
            } label: {
                Image(systemName: showingAddForm ? "xmark" : "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(showingAddForm ? .white.opacity(0.16) : .white.opacity(0.09)))
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }
}

// MARK: - Progress Bar

private struct HabitProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.10))
                if progress > 0 {
                    Capsule()
                        .fill(.green.opacity(0.85))
                        .frame(width: max(8, proxy.size.width * progress))
                }
            }
        }
        .frame(height: 5)
        .animation(.smooth(duration: 0.25), value: progress)
    }
}
