//
//  AxonExpandedView.swift
//  NotchAxonPlugin
//
//  Rich ambient panel rendered in the expanded notch surface.
//

import AppKit
import SwiftUI

public struct AxonExpandedView: View {
    @Bindable var plugin: AxonPlugin
    @State private var inputPrompt: String = ""
    @State private var isSubmitting: Bool = false
    @State private var submitSuccess: Bool = false

    public init(plugin: AxonPlugin) {
        self.plugin = plugin
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(plugin.isAxonOnline ? Color.emerald400 : Color.amber400)

                    Text("Axon Ambient Horizon")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(plugin.isAxonOnline ? "Connected" : "Offline")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(plugin.isAxonOnline ? Color.emerald900.opacity(0.6) : Color.amber900.opacity(0.6))
                        .foregroundStyle(plugin.isAxonOnline ? Color.emerald400 : Color.amber400)
                        .clipShape(Capsule())
                }

                Spacer()

                Button {
                    if let url = URL(string: "http://127.0.0.1:8082") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Dashboard")
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.gray)
                }
                .buttonStyle(.plain)
            }

            // Horizon Commitments
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY'S HORIZON")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.gray)

                if plugin.commitments.isEmpty {
                    Text("No upcoming commitments for today.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.gray.opacity(0.8))
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 6) {
                        ForEach(plugin.commitments.prefix(3)) { item in
                            horizonItemRow(item)
                        }
                    }
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.1))

            // Quick Ingest Bar
            VStack(alignment: .leading, spacing: 6) {
                Text("QUICK INGEST & ASSISTANT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.gray)

                HStack(spacing: 8) {
                    TextField("Paste URL or note for Axon...", text: $inputPrompt)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onSubmit {
                            submitIngest()
                        }

                    Button {
                        readPasteboard()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.gray)
                            .padding(7)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Paste from clipboard")

                    Button {
                        submitIngest()
                    } label: {
                        HStack(spacing: 4) {
                            if isSubmitting {
                                ProgressView()
                                    .controlSize(.small)
                            } else if submitSuccess {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.emerald400)
                            } else {
                                Text("Send")
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.emerald600)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
        }
        .padding(14)
        .frame(minWidth: 380, maxWidth: 440)
    }

    @ViewBuilder
    private func horizonItemRow(_ item: AxonCommitment) -> some View {
        HStack(spacing: 10) {
            // Urgency Indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(item.isNow ? Color.emerald400 : (item.isImminent ? Color.cyan : Color.gray.opacity(0.5)))
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let location = item.location, !location.isEmpty {
                        Text("• \(location)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.gray)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 6) {
                    Text(formatTimeRange(start: item.start, end: item.end))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.gray)

                    if let cat = item.category {
                        Text(cat.capitalized)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(categoryColor(cat))
                    }
                }
            }

            Spacer()

            Text(item.relativeTimeText)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(item.isNow || item.isImminent ? Color.emerald400 : Color.gray)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(item.isNow || item.isImminent ? Color.emerald900.opacity(0.5) : Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    private func categoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "committed": return Color.emerald400
        case "planned": return Color.blue
        default: return Color.gray
        }
    }

    private func readPasteboard() {
        if let string = NSPasteboard.general.string(forType: .string) {
            inputPrompt = string
        }
    }

    private func submitIngest() {
        let trimmed = inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSubmitting = true
        Task {
            let success = (try? await plugin.client.ingest(content: trimmed)) ?? false
            isSubmitting = false
            if success {
                submitSuccess = true
                inputPrompt = ""
                try? await Task.sleep(for: .seconds(2))
                submitSuccess = false
            }
        }
    }
}

private extension Color {
    static let emerald400 = Color(red: 52/255, green: 211/255, blue: 153/255)
    static let emerald600 = Color(red: 5/255, green: 150/255, blue: 105/255)
    static let emerald900 = Color(red: 6/255, green: 78/255, blue: 59/255)
    static let amber400 = Color(red: 251/255, green: 191/255, blue: 36/255)
    static let amber900 = Color(red: 120/255, green: 53/255, blue: 15/255)
}
