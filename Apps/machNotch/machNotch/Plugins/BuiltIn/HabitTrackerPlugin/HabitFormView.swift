//
//  HabitFormView.swift
//  machNotch
//
//  Inline add/edit form for habits — lives inside the expanded notch panel.
//

import SwiftUI
import AppKit

struct HabitFormView: View {
    let store: HabitStore
    let existingHabit: Habit?
    let onDone: () -> Void

    @State private var title: String
    @State private var selectedSymbol: String
    @State private var selectedColorHex: String
    @State private var customSymbolName: String

    private var isEditing: Bool { existingHabit != nil }
    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    init(store: HabitStore, existingHabit: Habit?, onDone: @escaping () -> Void) {
        self.store = store
        self.existingHabit = existingHabit
        self.onDone = onDone
        _title = State(initialValue: existingHabit?.title ?? "")
        _selectedSymbol = State(initialValue: existingHabit?.symbol ?? HabitStore.predefinedSymbols[0])
        _selectedColorHex = State(initialValue: existingHabit?.colorHex
            ?? (HabitStore.predefinedColors.randomElement()?.hexFormat ?? "#0066FF"))
        // Pre-populate custom field only when editing a non-standard symbol
        let sym = existingHabit?.symbol ?? ""
        _customSymbolName = State(initialValue: HabitStore.predefinedSymbols.contains(sym) ? "" : sym)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Row 1: name field + confirm/cancel
            HStack(spacing: 6) {
                TextField(isEditing ? "Habit name…" : "New habit…", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.08)))
                    .frame(maxWidth: .infinity)

                Button { onDone() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .contentShape(Circle())

                Button { save(); onDone() } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isValid ? .green : .white.opacity(0.25))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(isValid ? .green.opacity(0.18) : .white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .disabled(!isValid)
            }

            // Row 2: symbol picker + color picker
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(HabitStore.predefinedSymbols, id: \.self) { symbol in
                            Button { selectedSymbol = symbol; customSymbolName = "" } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 11))
                                    .foregroundStyle(selectedSymbol == symbol ? .white : .white.opacity(0.42))
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(selectedSymbol == symbol ? .white.opacity(0.18) : .white.opacity(0.06)))
                            }
                            .buttonStyle(.plain)
                            .contentShape(Circle())
                        }
                    }
                    .padding(.horizontal, 2)
                }

                Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 20)

                HStack(spacing: 5) {
                    ForEach(HabitStore.predefinedColors, id: \.self) { color in
                        Button { selectedColorHex = color.hexFormat } label: {
                            ZStack {
                                Circle().fill(color).frame(width: 16, height: 16)
                                if selectedColorHex.uppercased() == color.hexFormat.uppercased() {
                                    Circle().stroke(.white, lineWidth: 2).frame(width: 16, height: 16)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                    }
                }
            }

            // Row 3: custom SF symbol input
            HStack(spacing: 6) {
                Image(systemName: customSymbolName.isEmpty ? selectedSymbol : (isValidSymbol(customSymbolName) ? customSymbolName : selectedSymbol))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 20, height: 20)
                TextField("Custom SF Symbol…", text: $customSymbolName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .onChange(of: customSymbolName) { _, name in
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        if isValidSymbol(trimmed) { selectedSymbol = trimmed }
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.05)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
    }

    private func isValidSymbol(_ name: String) -> Bool {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        if var existing = existingHabit {
            existing.title = trimmedTitle
            existing.symbol = selectedSymbol
            existing.colorHex = selectedColorHex
            store.updateHabit(existing)
        } else {
            store.addHabit(Habit(title: trimmedTitle, symbol: selectedSymbol, colorHex: selectedColorHex))
        }
    }
}
