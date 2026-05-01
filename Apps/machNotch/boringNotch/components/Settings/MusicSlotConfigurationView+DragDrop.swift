//
//  MusicSlotConfigurationView+DragDrop.swift
//  boringNotch
//
//  Extracted drag and drop handling from MusicSlotConfigurationView.
//

import SwiftUI
import UniformTypeIdentifiers

extension MusicSlotConfigurationView {
    func handleDrop(_ providers: [NSItemProvider], toIndex: Int) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSString.self) {
                struct UncheckedSendableProvider: @unchecked Sendable {
                    let provider: NSItemProvider
                }
                let sendableProvider = UncheckedSendableProvider(provider: provider)
                sendableProvider.provider.loadObject(ofClass: NSString.self) { @Sendable item, error in
                    if let nsstring = item as? NSString {
                        let raw = nsstring as String
                        DispatchQueue.main.async {
                            self.processDropString(raw, toIndex: toIndex)
                        }
                    } else if let str = item as? String {
                        DispatchQueue.main.async {
                            self.processDropString(str, toIndex: toIndex)
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    func handleDropOnTrash(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSString.self) {
                struct UncheckedSendableProvider: @unchecked Sendable {
                    let provider: NSItemProvider
                }
                let sendableProvider = UncheckedSendableProvider(provider: provider)
                sendableProvider.provider.loadObject(ofClass: NSString.self) { @Sendable item, error in
                    if let nsstring = item as? NSString {
                        let raw = nsstring as String
                        DispatchQueue.main.async {
                            if raw.hasPrefix("slot:") {
                                let from = Int(raw.replacingOccurrences(of: "slot:", with: "")) ?? -1
                                guard from >= 0 && from < self.fixedSlotCount else { return }
                                var slots = self.settings.musicControlSlots
                                if from < slots.count {
                                    slots[from] = .none
                                    self.settings.musicControlSlots = slots
                                }
                            }
                        }
                    } else if let str = item as? String {
                        DispatchQueue.main.async {
                            if str.hasPrefix("slot:") {
                                let from = Int(str.replacingOccurrences(of: "slot:", with: "")) ?? -1
                                guard from >= 0 && from < self.fixedSlotCount else { return }
                                var slots = self.settings.musicControlSlots
                                if from < slots.count {
                                    slots[from] = .none
                                    self.settings.musicControlSlots = slots
                                }
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    func processDropString(_ raw: String, toIndex: Int) {
        if raw.hasPrefix("slot:") {
            let from = Int(raw.replacingOccurrences(of: "slot:", with: "")) ?? -1
            guard from >= 0 && from < fixedSlotCount else { return }
            var slots = settings.musicControlSlots
            if from < slots.count && toIndex < slots.count {
                slots.swapAt(from, toIndex)
                settings.musicControlSlots = slots
            }
        } else if raw.hasPrefix("control:") {
            let val = raw.replacingOccurrences(of: "control:", with: "")
            if let control = MusicControlButton(rawValue: val) {
                var slots = settings.musicControlSlots
                if let existing = slots.firstIndex(of: control), existing != toIndex {
                    slots[existing] = .none
                    settings.musicControlSlots = slots
                }
                updateSlot(control, at: toIndex)
            }
        }
    }

    func ensureSlotCapacity(_ target: Int) {
        guard target > settings.musicControlSlots.count else { return }
        let missing = target - settings.musicControlSlots.count
        settings.musicControlSlots.append(contentsOf: Array(repeating: .none, count: missing))
    }

    func slotValue(at index: Int) -> MusicControlButton {
        guard settings.musicControlSlots.indices.contains(index) else { return .none }
        return settings.musicControlSlots[index]
    }

    func updateSlot(_ value: MusicControlButton, at index: Int) {
        var slots = settings.musicControlSlots
        if index >= slots.count {
            slots.append(contentsOf: Array(repeating: .none, count: index - slots.count + 1))
        }
        slots[index] = value
        settings.musicControlSlots = slots
    }
}
