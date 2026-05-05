import SwiftUI
import SwiftData
import MachBriefKit

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredBriefEntry.revealedAt, order: .reverse) private var entries: [StoredBriefEntry]
    @State private var searchText = ""
    @State private var selectedSourceID = "all"
    @State private var favoritesOnly = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Picker("Source", selection: $selectedSourceID) {
                    Text("All").tag("all")
                    ForEach(BriefSourceRegistry.descriptors) { source in
                        Text(source.displayName).tag(source.id)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                Toggle("Favorites", isOn: $favoritesOnly)
                    .toggleStyle(.checkbox)
            }
            .padding(.horizontal)
            .padding(.top)

            List(filteredEntries) { item in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(BriefSourceRegistry.descriptor(for: item.sourceID).displayName) - \(item.revealedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        item.isFavorited.toggle()
                        try? modelContext.save()
                    } label: {
                        Image(systemName: item.isFavorited ? "star.fill" : "star")
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay {
                if filteredEntries.isEmpty {
                    ContentUnavailableView("No archived entries", systemImage: "archivebox")
                }
            }
        }
    }

    private var filteredEntries: [StoredBriefEntry] {
        let query = BriefArchiveQuery(
            sourceID: selectedSourceID == "all" ? nil : selectedSourceID,
            searchText: searchText,
            favoritesOnly: favoritesOnly
        )
        let allowedIDs = Set(entries.compactMap { $0.briefEntry() }.filtered(by: query).map(\.id))
        return entries.filter { allowedIDs.contains($0.id) }
    }
}
