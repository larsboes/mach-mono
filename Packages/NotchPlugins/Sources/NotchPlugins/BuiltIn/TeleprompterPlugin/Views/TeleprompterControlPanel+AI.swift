import SwiftUI

extension TeleprompterControlPanel {
    var aiSection: some View {
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

    func aiErrorBanner(_ message: String) -> some View {
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

    func refreshAIAvailability() async {
        guard settings.isAIEnabled, let ai = pluginManager?.services.ai else {
            isAIAvailable = false
            return
        }
        isAIAvailable = await ai.isAvailable
    }

    func performAIAction(_ action: TeleprompterAIAction) {
        guard let ai = pluginManager?.services.ai else { return }

        activeAIAction = action
        aiError = nil

        Task {
            defer {
                activeAIAction = nil
                Task { await refreshAIAvailability() }
            }
            do {
                try await state.aiAssistStream(action: action, ai: ai)
            } catch {
                aiError = error.localizedDescription
            }
        }
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
