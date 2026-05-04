import SwiftUI
import SwiftData

private enum BriefTab {
    case today, archive
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BriefTodayViewModel?
    @State private var selectedTab: BriefTab = .today

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Today").tag(BriefTab.today)
                Text("Archive").tag(BriefTab.archive)
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
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 340, height: 420)
        .task {
            guard viewModel == nil else { return }
            viewModel = BriefTodayViewModel(store: SwiftDataBriefStore(context: modelContext))
        }
    }
}
