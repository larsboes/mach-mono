import SwiftUI
import AppKit
import MachBriefKit
import UniformTypeIdentifiers

struct SourceSettingsView: View {
    @Bindable var viewModel: BriefTodayViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("Sources") {
                    VStack(alignment: .leading) {
                        ForEach(viewModel.sourceDescriptors) { source in
                            Toggle(isOn: Binding(
                                get: { viewModel.settings.enabledSourceIDs.contains(source.id) },
                                set: { viewModel.setSource(source.id, enabled: $0) }
                            )) {
                                Label(source.displayName, systemImage: source.systemImage)
                            }
                        }
                    }
                }

                GroupBox("Slot Assignment") {
                    VStack(alignment: .leading) {
                        ForEach(DailySlot.allCases, id: \.self) { slot in
                            Picker(slot.settingsLabel, selection: Binding(
                                get: { viewModel.settings.sourceID(for: slot) },
                                set: { viewModel.setAssignedSource($0, for: slot) }
                            )) {
                                ForEach(viewModel.sourceDescriptors) { source in
                                    Text(source.displayName).tag(source.id)
                                }
                            }
                        }
                    }
                }

                GroupBox("Vocabulary") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Language", selection: Binding(
                            get: { viewModel.settings.wordLanguageID },
                            set: { viewModel.setWordLanguage($0) }
                        )) {
                            ForEach(BriefLanguage.supported) { language in
                                Text(language.displayName).tag(language.id)
                            }
                        }

                        HStack {
                            Text(viewModel.settings.customWordListPath ?? "Using bundled \(viewModel.settings.wordLanguage.displayName) words")
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Custom JSON") {
                                chooseCustomWordList()
                            }
                            if viewModel.settings.customWordListPath != nil {
                                Button("Clear") {
                                    viewModel.setCustomWordListPath(nil)
                                }
                            }
                        }
                    }
                }

                GroupBox("Notifications") {
                    Toggle(isOn: Binding(
                        get: { viewModel.settings.notificationsEnabled },
                        set: { isEnabled in Task { await viewModel.setNotificationsEnabled(isEnabled) } }
                    )) {
                        Label("Daily slot notifications", systemImage: "bell")
                    }
                }

                GroupBox("Obsidian") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(viewModel.settings.obsidianNotePath ?? "No note selected")
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Choose") {
                                chooseObsidianNote()
                            }
                            Button("Test Write") {
                                Task { await viewModel.testObsidianWrite() }
                            }
                        }
                    }
                }

                GroupBox("Widget") {
                    Label("Add mach.brief from Notification Center widgets.", systemImage: "rectangle.grid.1x2")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }

    private func chooseObsidianNote() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md"),
            UTType(filenameExtension: "markdown"),
            .plainText,
        ].compactMap { $0 }
        if panel.runModal() == .OK {
            viewModel.setObsidianNotePath(panel.url?.path)
        }
    }

    private func chooseCustomWordList() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK {
            viewModel.setCustomWordListPath(panel.url?.path)
        }
    }
}

private extension DailySlot {
    var settingsLabel: String {
        switch self {
        case .morning: "06:00"
        case .midday: "12:00"
        case .afternoon: "18:00"
        case .evening: "00:00"
        }
    }
}
