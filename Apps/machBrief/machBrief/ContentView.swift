import SwiftUI
import SwiftData

private enum BriefTab {
    case today, archive, settings
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BriefTodayViewModel?
    @State private var selectedTab: BriefTab = .today
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Today").tag(BriefTab.today)
                Text("Archive").tag(BriefTab.archive)
                Text("Settings").tag(BriefTab.settings)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if let viewModel {
                switch selectedTab {
                case .today:
                    TodayView(viewModel: viewModel)
                case .archive:
                    ArchiveView()
                case .settings:
                    SourceSettingsView(viewModel: viewModel)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 380, height: 480)
        .task {
            guard viewModel == nil else { return }
            let model = BriefTodayViewModel(store: SwiftDataBriefStore(context: modelContext))
            viewModel = model
            await model.refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            guard let viewModel else { return }
            Task { await viewModel.refresh() }
        }
        .onChange(of: selectedTab) { _, _ in
            guard let viewModel else { return }
            Task { await viewModel.refresh() }
        }
    }
}
