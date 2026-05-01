import SwiftUI

/// Expanded panel for teleprompter — full-width two-column layout.
/// Left: script editor. Right: control panel. Bottom: action bar.
/// When "Present" is pressed, the notch closes and TeleprompterClosedView takes over.
struct TeleprompterExpandedView: View {
    @Bindable var state: TeleprompterState
    @Environment(BoringViewModel.self) var vm

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Two-Column Content (fills remaining space)
            HStack(alignment: .top, spacing: 10) {
                // Left: Script Editor (~60%)
                editorColumn

                // Right: Control Panel (~40%)
                ScrollView(.vertical, showsIndicators: false) {
                    TeleprompterControlPanel(state: state)
                }
                .frame(width: 250)
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .frame(maxHeight: .infinity)
            .clipped()

            // MARK: - Bottom Action Bar (fixed, always visible)
            actionBar
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .padding(.top, 4)
        }
        .onAppear {
            // Notch opened — stop scrolling so user can edit
            state.isScrolling = false
        }
        .onDisappear {
            state.timerManager.micMonitor.stopMonitoring()
        }
        .onChange(of: vm.notchState) {
            if vm.notchState == .closed {
                state.timerManager.micMonitor.stopMonitoring()
            }
        }
    }

    // MARK: - Editor Column

    private var editorColumn: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $state.text)
                .font(.system(size: 13, weight: .regular))
                .scrollContentBackground(.hidden)
                .textEditorStyle(.plain)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if state.text.isEmpty {
                Text("Type or paste your script here...")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(14)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.15))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 8) {
            // Left: utility actions
            Button(action: pasteFromClipboard) {
                Label("Paste", systemImage: "doc.on.clipboard")
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(ActionBarSecondaryStyle())
            .help("Paste from clipboard")

            Button(action: {
                state.text = ""
                state.reset()
            }) {
                Label("Clear", systemImage: "trash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(state.text.isEmpty ? Color.secondary.opacity(0.3) : Color.red.opacity(0.7))
            }
            .buttonStyle(ActionBarSecondaryStyle())
            .disabled(state.text.isEmpty)
            .help("Clear script")

            Spacer()

            // Right: primary actions
            if state.scrollPosition > 0 {
                Button(action: {
                    state.reset()
                }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(ActionBarSecondaryStyle())
                .help("Reset to beginning")
            }

            Button(action: startPresentation) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text(presentButtonTitle)
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(state.text.isEmpty
                            ? Color.white.opacity(0.05)
                            : Color.white.opacity(0.9))
                )
                .foregroundStyle(state.text.isEmpty ? .gray.opacity(0.3) : .black)
            }
            .buttonStyle(.plain)
            .disabled(state.text.isEmpty)
            .help("Start presenting")
        }
    }

    private var presentButtonTitle: String {
        if state.scrollPosition <= 0 { return "Present" }
        return state.isAtEnd ? "Restart" : "Resume"
    }

    // MARK: - Actions

    private func startPresentation() {
        vm.close(force: true)
        state.startPresentation()
    }

    private func pasteFromClipboard() {
        guard let content = NSPasteboard.general.string(forType: .string),
              !content.isEmpty else { return }
        state.text = content
        state.reset()
    }
}

// MARK: - Action Bar Button Style

private struct ActionBarSecondaryStyle: ButtonStyle {
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
