import WidgetKit
import SwiftUI
import MachBriefKit

struct BriefTimelineEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String?
}

struct BriefProvider: TimelineProvider {
    private let source = QuoteSource()

    func placeholder(in context: Context) -> BriefTimelineEntry {
        BriefTimelineEntry(date: .now, title: "Daily brief", subtitle: "Placeholder")
    }

    func getSnapshot(in context: Context, completion: @escaping (BriefTimelineEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BriefTimelineEntry>) -> Void) {
        Task {
            let now = Date()
            var entries: [BriefTimelineEntry] = []
            for slot in DailySlot.allCases {
                let entry = await source.entry(for: slot, date: now)
                entries.append(BriefTimelineEntry(date: now, title: entry.title, subtitle: entry.subtitle))
            }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(60 * 60))))
        }
    }
}

struct BriefWidgetEntryView: View {
    let entry: BriefTimelineEntry

    var body: some View {
        VStack(alignment: .leading) {
            Text(entry.title)
                .font(.headline)
            if let subtitle = entry.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(8)
    }
}

struct machBriefWidget: Widget {
    let kind: String = "machBriefWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BriefProvider()) { entry in
            BriefWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("mach.brief")
        .description("Current daily brief entry.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
