//
//  MusicSlotConfigurationView.swift
//  boringNotch
//
//  Created by Alexander on 2025-11-17.
//

import SwiftUI
import UniformTypeIdentifiers

struct MusicSlotConfigurationView: View {
    @Environment(\.bindableSettings) var settings
    @Environment(\.pluginManager) var pluginManager

    var musicService: (any MusicServiceProtocol)? {
        pluginManager?.services.music
    }

    @State var draggedSlot: MusicControlButton?
    let fixedSlotCount: Int = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            slotConfigurationSection

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    withAnimation {
                        settings.musicControlSlots = MusicControlButton.defaultLayout
                    }
                }
                .buttonStyle(.borderless)
            }
        }
        .onAppear {
            ensureSlotCapacity(fixedSlotCount)
        }
    }

    var previewSection: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(0..<fixedSlotCount, id: \.self) { index in
                    let slot = slotValue(at: index)
                    Group {
                        if slot != .none {
                            slotPreview(for: slot)
                                .frame(maxWidth: 44)
                                .onDrag {
                                    DispatchQueue.main.async { draggedSlot = slot }
                                    return NSItemProvider(object: NSString(string: "slot:\(index)"))
                                }
                                .onDrop(of: [UTType.plainText.identifier], isTargeted: nil) { providers in
                                    let handled = handleDrop(providers, toIndex: index)
                                    DispatchQueue.main.async { draggedSlot = nil }
                                    return handled
                                }
                        } else {
                            slotPreview(for: slot)
                                .frame(maxWidth: 44)
                                .onDrop(of: [UTType.plainText.identifier], isTargeted: nil) { providers in
                                    let handled = handleDrop(providers, toIndex: index)
                                    DispatchQueue.main.async { draggedSlot = nil }
                                    return handled
                                }
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .frame(width: 56, height: 56)
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.primary)
                }
                .cornerRadius(10)
                .contentShape(RoundedRectangle(cornerRadius: 10))
                .onDrop(of: [UTType.plainText.identifier], isTargeted: nil) { providers in
                    return handleDropOnTrash(providers)
                }
                Text("Clear slot")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 72)
            }
        }
    }

    var slotConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Layout Preview")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Drag items in the preview to reorder or drop from the palette")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            previewSection
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Drag a control onto a slot")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(MusicControlButton.pickerOptions, id: \.self) { control in
                            VStack(spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .frame(width: 44, height: 44)
                                    if control != .none {
                                        Image(systemName: control.iconName)
                                            .font(.system(size: control.prefersLargeScale ? 18 : 15, weight: .medium))
                                            .foregroundStyle(control == .none ? Color.secondary : Color.primary)
                                            .frame(width: 28, height: 28)
                                    }
                                }
                                .cornerRadius(8)
                                .contentShape(RoundedRectangle(cornerRadius: 8))
                                .onDrag {
                                    return NSItemProvider(object: NSString(string: "control:\(control.rawValue)"))
                                }
                                .onTapGesture {
                                    if let idx = settings.musicControlSlots.firstIndex(of: .none) {
                                        updateSlot(control, at: idx)
                                    } else {
                                        withAnimation { updateSlot(control, at: 0) }
                                    }
                                }
                                Text(control.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.visible)
            }
        }
    }

    @ViewBuilder
    func slotPreview(for slot: MusicControlButton) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .frame(width: 44, height: 44)
            if slot != .none {
                Image(systemName: slot.iconName)
                    .font(.system(size: slot.prefersLargeScale ? 18 : 15, weight: .medium))
                    .foregroundStyle(previewIconColor(for: slot))
                    .frame(width: 28, height: 28)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .frame(width: 32, height: 32)
            }
        }
        .cornerRadius(8)
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    private func previewIconColor(for slot: MusicControlButton) -> Color {
        switch slot {
        case .shuffle:
            return (musicService?.isShuffled ?? false) ? .red : .primary
        case .repeatMode:
            return (musicService?.repeatMode ?? .off) != .off ? .red : .primary
        case .favorite:
            return (musicService?.isFavorite ?? false) ? .red : .primary
        case .playPause:
            return .primary
        default:
            return .primary
        }
    }
}
