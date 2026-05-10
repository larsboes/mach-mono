//
//  BriefSettingsView.swift
//  machNotch
//

import SwiftUI
import MachBriefKit

struct BriefSettingsView: View {
    @State private var settings = BriefSettingsCoding.load()
    
    var body: some View {
        Form {
            Section(header: Text("Vocabulary")) {
                Picker("Language", selection: $settings.wordLanguageID) {
                    ForEach(BriefLanguage.supported) { lang in
                        Text(lang.displayName).tag(lang.id)
                    }
                }
                Picker("Level", selection: Binding(
                    get: { settings.vocabularyLevel },
                    set: { settings.vocabularyLevel = $0 }
                )) {
                    Text("All words").tag(Optional<VocabularyLevel>.none)
                    ForEach(VocabularyLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(Optional(level))
                    }
                }
            }

            Section(header: Text("General")) {
                Toggle("Enable Notifications", isOn: $settings.notificationsEnabled)
            }
            
            Section(header: Text("Slot Assignments")) {
                Picker("Morning", selection: binding(for: .morning)) {
                    ForEach(BriefSourceRegistry.defaultSourceIDs, id: \.self) { sourceID in
                        Text(BriefSourceRegistry.descriptor(for: sourceID).displayName).tag(sourceID)
                    }
                }
                Picker("Midday", selection: binding(for: .midday)) {
                    ForEach(BriefSourceRegistry.defaultSourceIDs, id: \.self) { sourceID in
                        Text(BriefSourceRegistry.descriptor(for: sourceID).displayName).tag(sourceID)
                    }
                }
                Picker("Afternoon", selection: binding(for: .afternoon)) {
                    ForEach(BriefSourceRegistry.defaultSourceIDs, id: \.self) { sourceID in
                        Text(BriefSourceRegistry.descriptor(for: sourceID).displayName).tag(sourceID)
                    }
                }
                Picker("Evening", selection: binding(for: .evening)) {
                    ForEach(BriefSourceRegistry.defaultSourceIDs, id: \.self) { sourceID in
                        Text(BriefSourceRegistry.descriptor(for: sourceID).displayName).tag(sourceID)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings) { _, newValue in
            BriefSettingsCoding.save(newValue)
            // Post after a short delay so rapid picker interactions coalesce into one reload
            Task { @MainActor in
    try? await Task.sleep(nanoseconds: 300000000)
NotificationCenter.default.post(name: .briefSettingsDidChange, object: nil)
            }
        }
    }
    
    private func binding(for slot: DailySlot) -> Binding<String> {
        Binding(
            get: { self.settings.slotAssignments[slot] ?? BriefSettings.defaultSlotAssignments[slot] ?? "quote" },
            set: { self.settings.slotAssignments[slot] = $0 }
        )
    }
}
