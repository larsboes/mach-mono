import SwiftUI
import MachBriefKit

struct TodayView: View {
    @Bindable var viewModel: BriefTodayViewModel

    var body: some View {
        VStack(spacing: 16) {
            if let entry = viewModel.currentEntry {
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.title)
                        .font(.title3.weight(.semibold))
                    if let subtitle = entry.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let body = entry.body {
                        Text(body)
                            .font(.body)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                ContentUnavailableView("No entry yet", systemImage: "book.closed")
            }
            SourceSettingsView(viewModel: viewModel)
        }
        .padding()
        .task {
            await viewModel.refresh()
        }
    }
}
