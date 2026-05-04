import Foundation
import Observation
import MachBriefKit

@MainActor
@Observable
final class BriefTodayViewModel {
    var currentEntry: BriefEntry?
    var selectedSourceID: String = "quote"
    var enabledSources: Set<String> = ["quote", "fact", "mantra", "word", "mood"]

    private let scheduler = DailyScheduler()
    private var sourceByID: [String: any BriefSource] = [
        "quote": QuoteSource(),
        "fact": FactSource(),
        "mantra": MantraSource(),
        "word": WordSource(),
        "mood": MoodCheckInSource()
    ]
    private let store: any BriefStore

    init(store: any BriefStore) {
        self.store = store
    }

    func refresh(date: Date = Date()) async {
        let slot = scheduler.slot(for: date)
        let sourceID = enabledSources.contains(selectedSourceID) ? selectedSourceID : "quote"
        guard let source = sourceByID[sourceID] else { return }
        let entry = await source.entry(for: slot, date: date)
        currentEntry = entry
        await store.save(entry)
    }
}
