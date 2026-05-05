import XCTest
@testable import MachBriefKit

final class MachBriefKitTests: XCTestCase {
    func testSlotBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let scheduler = DailyScheduler(calendar: calendar)

        XCTAssertEqual(scheduler.slot(for: date(hour: 0, calendar: calendar)), .evening)
        XCTAssertEqual(scheduler.slot(for: date(hour: 6, calendar: calendar)), .morning)
        XCTAssertEqual(scheduler.slot(for: date(hour: 12, calendar: calendar)), .midday)
        XCTAssertEqual(scheduler.slot(for: date(hour: 18, calendar: calendar)), .afternoon)
    }

    func testDefaultSourceAssignmentsPutMoodAtEighteenHundred() {
        let settings = BriefSettings()
        XCTAssertEqual(settings.sourceID(for: .morning), "word")
        XCTAssertEqual(settings.sourceID(for: .midday), "fact")
        XCTAssertEqual(settings.sourceID(for: .afternoon), "mood")
        XCTAssertEqual(settings.sourceID(for: .evening), "quote")
    }

    func testQuoteSourceIsDeterministicForSlotAndDate() async {
        let scheduler = DailyScheduler(calendar: Calendar(identifier: .gregorian))
        let source = QuoteSource(scheduler: scheduler)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = await source.entry(for: .morning, date: date)
        let second = await source.entry(for: .morning, date: date)
        XCTAssertEqual(first.title, second.title)
        XCTAssertEqual(first.subtitle, second.subtitle)
    }

    func testWordSourceCarriesVocabMetadata() async {
        let source = WordSource(
            dictionaryClient: EmptyDictionaryClient(),
            words: [
                WordItem(
                    word: "ineffable",
                    definition: "Too great to be expressed in words.",
                    partOfSpeech: "adjective",
                    phonetic: "/in-EF-uh-buhl/",
                    example: "The quiet had an ineffable warmth."
                )
            ]
        )

        let entry = await source.entry(for: .morning, date: .now)
        XCTAssertEqual(entry.title, "ineffable")
        XCTAssertEqual(entry.metadata["kind"], "word")
        XCTAssertEqual(entry.metadata["partOfSpeech"], "adjective")
        XCTAssertEqual(entry.metadata["phonetic"], "/in-EF-uh-buhl/")
        XCTAssertEqual(entry.metadata["example"], "The quiet had an ineffable warmth.")
    }

    func testGermanWordSourceUsesGermanLanguageMetadata() async {
        let source = WordSource(dictionaryClient: EmptyDictionaryClient(), language: .german)

        let entry = await source.entry(for: .morning, date: .now)
        XCTAssertEqual(entry.metadata["kind"], "word")
        XCTAssertEqual(entry.metadata["language"], "de")
        XCTAssertFalse(entry.title.isEmpty)
        XCTAssertNotNil(entry.body)
    }

    func testEngineUsesSettingsLanguageForWordEntries() async {
        let engine = BriefEngine()
        let settings = BriefSettings(
            enabledSourceIDs: ["word"],
            slotAssignments: [.morning: "word"],
            wordLanguageID: "de"
        )

        let entry = await engine.entry(for: .morning, date: .now, settings: settings)
        XCTAssertEqual(entry.sourceID, "word")
        XCTAssertEqual(entry.metadata["language"], "de")
    }

    func testEngineDoesNotDuplicateEntriesForSameSlotAndDay() async {
        let store = InMemoryBriefStore(calendar: Calendar(identifier: .gregorian))
        let engine = BriefEngine(scheduler: DailyScheduler(calendar: Calendar(identifier: .gregorian)))
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let first = await engine.ensureEntry(for: date, settings: BriefSettings(), store: store)
        let second = await engine.ensureEntry(for: date, settings: BriefSettings(), store: store)
        let entries = await store.entries()

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(entries.count, 1)
    }

    func testArchiveFilteringSearchAndFavorites() async {
        let store = InMemoryBriefStore()
        let favorite = BriefEntry(sourceID: "quote", slot: .morning, title: "Steady work", subtitle: "A", body: "Focus", isFavorited: true, revealedAt: .now)
        let other = BriefEntry(sourceID: "fact", slot: .midday, title: "Moon fact", subtitle: nil, body: nil, revealedAt: .now)

        await store.save(favorite)
        await store.save(other)

        let favorites = await store.entries(matching: BriefArchiveQuery(searchText: "steady", favoritesOnly: true))
        let facts = await store.entries(matching: BriefArchiveQuery(sourceID: "fact"))

        XCTAssertEqual(favorites.map(\.id), [favorite.id])
        XCTAssertEqual(facts.map(\.id), [other.id])
    }

    func testFavoriteMutationAndMoodStorage() async {
        let store = InMemoryBriefStore()
        let entry = BriefEntry(sourceID: "mood", slot: .afternoon, title: "How are you feeling?", revealedAt: .now)
        await store.save(entry)

        await store.updateFavorite(entryID: entry.id, isFavorited: true)
        await store.saveMoodResponse(entryID: entry.id, rating: .good, note: "clear afternoon")

        let updated = await store.entries().first
        XCTAssertEqual(updated?.isFavorited, true)
        XCTAssertEqual(updated?.metadata["moodRating"], "good")
        XCTAssertEqual(updated?.metadata["moodNote"], "clear afternoon")
    }

    func testObsidianMarkdownOutput() {
        let entry = BriefEntry(
            sourceID: "word",
            slot: .morning,
            title: "lucid",
            subtitle: "adjective",
            body: "Expressed clearly.",
            revealedAt: date(hour: 6, calendar: Calendar(identifier: .gregorian))
        )

        let markdown = ObsidianSink.markdown(for: entry, calendar: Calendar(identifier: .gregorian))
        XCTAssertTrue(markdown.contains("## Daily Brief - 06:00"))
        XCTAssertTrue(markdown.contains("**Word:** lucid"))
        XCTAssertTrue(markdown.contains("> Expressed clearly."))
    }

    func testWidgetTimelineDatesAndNotificationPlan() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let engine = BriefEngine(scheduler: DailyScheduler(calendar: calendar))
        let day = date(hour: 9, calendar: calendar)

        let timeline = await engine.timelineEntries(for: day, settings: BriefSettings())
        let plan = BriefNotificationPlanner.plan(for: timeline)

        XCTAssertEqual(timeline.map { calendar.component(.hour, from: $0.date) }, [0, 6, 12, 18])
        XCTAssertEqual(plan.count, 4)
        XCTAssertEqual(plan.map(\.identifier), ["machbrief-3", "machbrief-0", "machbrief-1", "machbrief-2"])
    }

    private func date(hour: Int, calendar: Calendar) -> Date {
        DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 5, day: 5, hour: hour).date!
    }
}

private struct EmptyDictionaryClient: DictionaryAPIClientProtocol {
    func lookup(word: String, languageCode: String) async -> DictionaryWordDetail? {
        nil
    }
}
