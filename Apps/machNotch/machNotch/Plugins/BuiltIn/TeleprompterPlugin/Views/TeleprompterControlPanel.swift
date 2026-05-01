import SwiftUI

/// Right column of the teleprompter expanded panel — mode, speed, display, AI, script info.
struct TeleprompterControlPanel: View {
    @Bindable var state: TeleprompterState
    @Environment(\.pluginManager) var pluginManager
    @Environment(\.settings) var settings

    @State private var isAIProcessing: Bool = false
    @State private var aiError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // MARK: - Speed Controls
            speedSection

            Divider().opacity(0.3)

            // MARK: - Display Settings
            displaySection

            Divider().opacity(0.3)

            // MARK: - AI Actions
            if settings.isAIEnabled && !state.text.isEmpty {
                aiSection
            }

            Spacer(minLength: 0)

            // MARK: - Script Info
            if !state.text.isEmpty {
                scriptInfoSection
            }
        }
        .overlay {
            if let error = aiError {
                aiErrorBanner(error)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    // MARK: - Speed

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Speed")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Button(action: { state.decreaseSpeed() }) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(CompactControlStyle())

                Text("\(Int(state.config.speed)) px/s")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(minWidth: 60)

                Button(action: { state.increaseSpeed() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(CompactControlStyle())
            }
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Display")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            // Font size
            HStack(spacing: 4) {
                Text("Size")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: 30, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { state.config.fontSize },
                        set: { state.config.fontSize = $0 }
                    ),
                    in: 10...40,
                    step: 1
                )
                .controlSize(.mini)

                Text("\(Int(state.config.fontSize))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }

            // Text color swatches
            HStack(spacing: 4) {
                Text("Color")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: 30, alignment: .leading)

                ForEach(PrompterColor.allCases, id: \.self) { color in
                    Circle()
                        .fill(color.color)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    state.textColor == color ? Color.accentColor : Color.clear,
                                    lineWidth: 2
                                )
                                .frame(width: 18, height: 18)
                        )
                        .onTapGesture {
                            state.textColor = color
                        }
                }
            }
        }
    }

    // MARK: - AI Actions

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AI Assist")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                CompactAIButton(title: "Refine", icon: "sparkles") {
                    performAIAction(.refine)
                }
                CompactAIButton(title: "Summarize", icon: "text.badge.minus") {
                    performAIAction(.summarize)
                }
                CompactAIButton(title: "Intro", icon: "mic.badge.plus") {
                    performAIAction(.draftIntro)
                }
            }
            .disabled(isAIProcessing)
            .opacity(isAIProcessing ? 0.5 : 1.0)
        }
    }

    // MARK: - Script Info

    private var scriptInfoSection: some View {
        let wordCount = state.text.split(whereSeparator: \.isWhitespace).count
        let estimatedMinutes = Double(wordCount) / 150.0 // ~150 wpm speaking pace
        let sections = state.text.components(separatedBy: "\n")
            .filter { $0.hasPrefix("##") }.count

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Label("\(wordCount) words", systemImage: "text.word.spacing")
                if sections > 0 {
                    Label("\(sections) sections", systemImage: "list.bullet")
                }
            }
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)

            Text("~\(String(format: "%.0f", ceil(estimatedMinutes)))m reading time")
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - AI Error Banner

    private func aiErrorBanner(_ message: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
            Text(message)
                .font(.system(size: 9))
                .lineLimit(1)
            Spacer()
            Button { aiError = nil } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(4)
    }

    // MARK: - AI Action

    private func performAIAction(_ action: TeleprompterAIAction) {
        guard let ai = pluginManager?.services.ai else { return }

        isAIProcessing = true
        aiError = nil

        Task {
            do {
                try await state.aiAssist(action: action, ai: ai)
                isAIProcessing = false
            } catch {
                aiError = error.localizedDescription
                isAIProcessing = false
            }
        }
    }
}

// MARK: - PrompterColor SwiftUI Extension

extension PrompterColor {
    var color: Color {
        switch self {
        case .white: .white
        case .warmWhite: Color(red: 1.0, green: 0.95, blue: 0.88)
        case .yellow: .yellow
        case .green: .green
        case .cyan: .cyan
        }
    }
}

// MARK: - Compact Button Styles

private struct CompactControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 24, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
            )
            .foregroundStyle(.white.opacity(0.8))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

private struct CompactAIButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 9, weight: .semibold))
            .padding(.vertical, 4)
            .padding(.horizontal, 7)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
