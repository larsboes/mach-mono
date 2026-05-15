import SwiftUI

/// Right column of the teleprompter expanded panel — mode, speed, display, AI, script info.
struct TeleprompterControlPanel: View {
    @Bindable var state: TeleprompterState
    @Environment(\.pluginManager) var pluginManager
    @Environment(\.settings) var settings

    @State private var activeAIAction: TeleprompterAIAction? = nil
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
            if settings.isAIEnabled {
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

            HStack(spacing: 4) {
                Text("Color")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: 30, alignment: .leading)

                PrompterColorPicker(selection: $state.textColor)
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
                CompactAIButton(title: "Refine", icon: "sparkles", isLoading: activeAIAction == .refine) {
                    performAIAction(.refine)
                }
                CompactAIButton(title: "Summarize", icon: "text.badge.minus", isLoading: activeAIAction == .summarize) {
                    performAIAction(.summarize)
                }
                CompactAIButton(title: "Intro", icon: "mic.badge.plus", isLoading: activeAIAction == .draftIntro) {
                    performAIAction(.draftIntro)
                }
            }
            .disabled(activeAIAction != nil || state.text.isEmpty)
        }
    }

    // MARK: - Script Info

    private var wordCount: Int {
        state.text.split(whereSeparator: \.isWhitespace).count
    }

    private var sectionCount: Int {
        state.text.components(separatedBy: "\n").filter { $0.hasPrefix("##") }.count
    }

    private var scriptInfoSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Label("\(wordCount) words", systemImage: "text.word.spacing")
                if sectionCount > 0 {
                    Label("\(sectionCount) sections", systemImage: "list.bullet")
                }
            }
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)

            Text("~\(String(format: "%.0f", ceil(Double(wordCount) / 150.0)))m reading time")
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
            Button {
                aiError = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - AI Action

    private func performAIAction(_ action: TeleprompterAIAction) {
        guard let ai = pluginManager?.services.ai else { return }

        activeAIAction = action
        aiError = nil

        Task {
            defer { activeAIAction = nil }
            do {
                try await state.aiAssist(action: action, ai: ai)
            } catch {
                aiError = error.localizedDescription
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

// MARK: - Color Picker

struct PrompterColorPicker: View {
    @Binding var selection: PrompterColor

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PrompterColor.allCases, id: \.self) { color in
                Circle()
                    .fill(color.color)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .strokeBorder(selection == color ? Color.accentColor : Color.clear, lineWidth: 2)
                            .frame(width: 18, height: 18)
                    )
                    .onTapGesture { selection = color }
            }
        }
    }
}

// MARK: - Button Styles

struct ActionBarSecondaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
            )
            .foregroundStyle(.secondary)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

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
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.secondary)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.system(size: 9, weight: .semibold))
        }
        .buttonStyle(ActionBarSecondaryStyle())
    }
}
