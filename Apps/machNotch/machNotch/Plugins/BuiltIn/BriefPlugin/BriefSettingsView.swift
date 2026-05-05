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
            Section(header: Text("General")) {
                Toggle("Enable Notifications", isOn: $settings.notificationsEnabled)
                
                Picker("Word Language", selection: $settings.wordLanguageID) {
                    ForEach(BriefLanguage.supported) { lang in
                        Text(lang.displayName).tag(lang.id)
                    }
                }
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
            NotificationCenter.default.post(name: NSNotification.Name("briefSettingsDidChange"), object: nil)
        }
    }
    
    private func binding(for slot: DailySlot) -> Binding<String> {
        Binding(
            get: { self.settings.slotAssignments[slot] ?? BriefSettings.defaultSlotAssignments[slot] ?? "quote" },
            set: { self.settings.slotAssignments[slot] = $0 }
        )
    }
}
