import SwiftUI

struct SourceSettingsView: View {
    @Bindable var viewModel: BriefTodayViewModel
    private let orderedSourceIDs = ["quote", "fact", "mantra", "word", "mood"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources")
                .font(.headline)
            ForEach(orderedSourceIDs, id: \.self) { sourceID in
                Toggle(isOn: Binding(
                    get: { viewModel.enabledSources.contains(sourceID) },
                    set: { isOn in
                        if isOn {
                            viewModel.enabledSources.insert(sourceID)
                        } else {
                            viewModel.enabledSources.remove(sourceID)
                        }
                    }
                )) {
                    Text(sourceID.capitalized)
                }
            }
            Picker("Active Source", selection: $viewModel.selectedSourceID) {
                ForEach(orderedSourceIDs, id: \.self) { sourceID in
                    Text(sourceID.capitalized).tag(sourceID)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
