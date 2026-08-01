import WidgetKit
import SwiftUI
import MachBriefKit

struct BriefTimelineEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String?
    let body: String?
    let sourceID: String
    let metadata: [String: String]
}

struct BriefProvider: TimelineProvider {
    private let engine = BriefEngine()
    private let calendar = Calendar.current

    func placeholder(in context: Context) -> BriefTimelineEntry {
        BriefTimelineEntry(date: .now, title: "lucid", subtitle: "(adjective.) /LOO-sid/", body: "Clear, easy to understand, or mentally sharp.", sourceID: "word", metadata: ["kind": "word"])
    }

    func getSnapshot(in context: Context, completion: @escaping (BriefTimelineEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BriefTimelineEntry>) -> Void) {
        Task {
            let now = Date()
            let settings = BriefSettingsCoding.load()
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            let allItems = (
                await engine.timelineEntries(for: now, settings: settings)
            ) + (
                await engine.timelineEntries(for: tomorrow, settings: settings)
            )

            let sorted = allItems.sorted { $0.date < $1.date }
            let currentIndex = max(
                0,
                sorted.lastIndex { $0.date <= now } ?? 0
            )
            let visibleItems = Array(sorted[currentIndex...]).prefix(4)
            let entries = visibleItems.map { item in
                BriefTimelineEntry(
                    date: item.date,
                    title: item.entry.title,
                    subtitle: item.entry.subtitle,
                    body: item.entry.body,
                    sourceID: item.entry.sourceID,
                    metadata: item.entry.metadata
                )
            }

            let refreshDate = entries.dropFirst().first?.date ?? now.addingTimeInterval(60 * 60 * 6)
            completion(Timeline(entries: Array(entries), policy: .after(refreshDate)))
        }
    }
}

struct BriefWidgetEntryView: View {
    let entry: BriefTimelineEntry

    var body: some View {
        if entry.sourceID == "word" {
            VStack(alignment: .leading, spacing: 7) {
                Text(entry.title.lowercased())
                    .font(.system(.title2, design: .serif).weight(.bold))
                    .foregroundStyle(Color(red: 0.13, green: 0.13, blue: 0.12))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(red: 0.36, green: 0.45, blue: 0.43))
                        .lineLimit(1)
                }
                if let body = entry.body {
                    Text(body)
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.24, green: 0.25, blue: 0.23))
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                Label("Word", systemImage: "textformat.abc")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.36, green: 0.45, blue: 0.43))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(12)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.94, blue: 0.88),
                        Color(red: 0.80, green: 0.90, blue: 0.88),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            VStack(alignment: .leading) {
                Label(BriefSourceRegistry.descriptor(for: entry.sourceID).displayName, systemImage: BriefSourceRegistry.descriptor(for: entry.sourceID).systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(3)
                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let body = entry.body {
                    Text(body)
                        .font(.caption2)
                        .lineLimit(3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(8)
        }
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
