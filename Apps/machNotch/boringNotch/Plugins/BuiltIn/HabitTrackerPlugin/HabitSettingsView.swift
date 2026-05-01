//
//  HabitSettingsView.swift
//  boringNotch
//

import SwiftUI

struct HabitSettingsView: View {
    let plugin: HabitTrackerPlugin
    private var store: HabitStore { plugin.store }
    
    @State private var showingAddHabit = false
    @State private var newHabitTitle = ""
    @State private var newHabitColor: Color = .blue
    @State private var newHabitSymbol = "star.fill"
    
    @Environment(\.bindableSettings) var settings
    
    var body: some View {
        @Bindable var settings = settings
        
        Form {
            Section {
                Toggle(isOn: $settings.showHabitTracker) {
                    Text("Enable Habit Tracker")
                }
            }
            
            if settings.showHabitTracker {
            
            // Habits List
            List {
                ForEach(store.habits) { habit in
                    HStack {
                        Image(systemName: habit.symbol)
                            .foregroundColor(habit.color)
                            .frame(width: 24, alignment: .center)
                        
                        Text(habit.title)
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { habit.isActive },
                            set: { newValue in
                                var modified = habit
                                modified.isActive = newValue
                                store.updateHabit(modified)
                            }
                        ))
                        .labelsHidden()
                        
                        Button(role: .destructive, action: {
                            store.deleteHabit(id: habit.id)
                        }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                        .padding(.leading, 8)
                    }
                }
            }
            .frame(height: 200)
            .cornerRadius(8)
            
            // Add New Habit
            VStack(alignment: .leading, spacing: 8) {
                Text("Add New Habit")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    TextField("Habit name...", text: $newHabitTitle)
                        .textFieldStyle(.roundedBorder)
                    
                    ColorPicker("", selection: $newHabitColor)
                        .labelsHidden()
                    
                    Picker("Symbol", selection: $newHabitSymbol) {
                        ForEach(HabitStore.predefinedSymbols, id: \.self) { symbol in
                            Image(systemName: symbol)
                                .tag(symbol)
                        }
                    }
                    .frame(width: 60)
                    .labelsHidden()
                    
                    Button("Add") {
                        let habit = Habit(
                            title: newHabitTitle,
                            symbol: newHabitSymbol,
                            colorHex: newHabitColor.hexFormat,
                            isActive: true
                        )
                        store.addHabit(habit)
                        
                        // Reset form
                        newHabitTitle = ""
                        newHabitColor = HabitStore.predefinedColors.randomElement() ?? .blue
                    }
                    .disabled(newHabitTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            
            // Stats & Data
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Habits: \(store.habits.count)")
                    Text("Total Completions: \(store.completions.count)")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
                
                Spacer()
            }
            }
        }
        .padding()
        .frame(width: 450)
    }
}
