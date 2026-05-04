import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Query(sort: \StoredBriefEntry.revealedAt, order: .reverse) private var entries: [StoredBriefEntry]

    var body: some View {
        List(entries) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(item.revealedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Archive")
    }
}
