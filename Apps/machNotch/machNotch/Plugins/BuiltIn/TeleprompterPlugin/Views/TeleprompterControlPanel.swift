import SwiftUI

/// Right column of the teleprompter expanded panel — mode, speed, display, AI, script info.
struct TeleprompterControlPanel: View {
    @Bindable var state: TeleprompterState
    @Environment(\.pluginManager) var pluginManager
    @Environment(\.settings) var settings

    @State var activeAIAction: TeleprompterAIAction? = nil
    @State var aiError: String?
    @State var isAIAvailable = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // MARK: - Speed Controls
            speedSection

            Divider().opacity(0.3)

            // MARK: - Display Settings
            displaySection

            Divider().opacity(0.3)

            // MARK: - AI Actions
            if settings.isAIEnabled && isAIAvailable {
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
        .task {
            await refreshAIAvailability()
        }
        .onChange(of: settings.isAIEnabled) { _, _ in
            Task { await refreshAIAvailability() }
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
