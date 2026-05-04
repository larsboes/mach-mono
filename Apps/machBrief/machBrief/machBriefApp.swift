import SwiftUI
import SwiftData

@main
struct machBriefApp: App {
    private let modelContainer: ModelContainer = {
        let schema = Schema([StoredBriefEntry.self])
        return try! ModelContainer(for: schema)
    }()

    var body: some Scene {
        MenuBarExtra("mach.brief", systemImage: "text.book.closed") {
            ContentView()
                .modelContainer(modelContainer)
        }
        .menuBarExtraStyle(.window)
    }
}
