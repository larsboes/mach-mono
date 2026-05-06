import Foundation

public struct BriefEngine: Sendable {
    private let scheduler: DailyScheduler
    private let sources: [String: any BriefSource]

    public init(
        scheduler: DailyScheduler = DailyScheduler(),
        sources: [String: any BriefSource] = BriefSourceRegistry.makeSources()
    ) {
        self.scheduler = scheduler
        self.sources = sources
    }

    public func currentSlot(for date: Date = Date()) -> DailySlot {
        scheduler.slot(for: date)
    }

    public func entry(for date: Date = Date(), settings: BriefSettings) async -> BriefEntry {
        await entry(for: scheduler.slot(for: date), date: date, settings: settings)
    }

    public func entry(for slot: DailySlot, date: Date, settings: BriefSettings) async -> BriefEntry {
        let sourceID = settings.sourceID(for: slot)
        if sourceID == "word" {
            let customURL = settings.customWordListPath.map { URL(fileURLWithPath: $0) }
            return await WordSource(language: settings.wordLanguage, customWordsURL: customURL).entry(for: slot, date: date)
        } else if sourceID == "mood" {
            return await MoodCheckInSource(language: settings.wordLanguage).entry(for: slot, date: date)
        }
        let source = sources[sourceID] ?? sources["quote"] ?? QuoteSource()
        return await source.entry(for: slot, date: date)
    }

    public func ensureEntry(
        for date: Date = Date(),
        settings: BriefSettings,
        store: any BriefStore,
        sinks: [any BriefSink] = []
    ) async -> BriefEntry {
        let slot = scheduler.slot(for: date)
        if let existing = await store.entry(for: date, slot: slot) {
            return existing
        }
        let entry = await entry(for: slot, date: date, settings: settings)
        await store.save(entry)
        for sink in sinks {
            await sink.receive(entry)
        }
        return entry
    }

    public func timelineEntries(for day: Date, settings: BriefSettings) async -> [BriefTimelineItem] {
        let items = await DailySlot.allCases.asyncMap { slot in
            let date = scheduler.date(for: slot, on: day)
            let entry = await entry(for: slot, date: date, settings: settings)
            return BriefTimelineItem(date: date, entry: entry)
        }
        return items.sorted { $0.date < $1.date }
    }
}

public struct BriefTimelineItem: Sendable {
    public let date: Date
    public let entry: BriefEntry

    public init(date: Date, entry: BriefEntry) {
        self.date = date
        self.entry = entry
    }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async -> T) async -> [T] {
        var values: [T] = []
        values.reserveCapacity(count)
        for element in self {
            let value = await transform(element)
            values.append(value)
        }
        return values
    }
}
