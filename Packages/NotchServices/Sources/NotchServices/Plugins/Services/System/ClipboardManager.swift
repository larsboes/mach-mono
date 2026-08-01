import AppKit
import Foundation
import SQLite

public struct ClipboardItem: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let content: String
    public let timestamp: Date
    public let type: String  // "text", "image", etc.

    public init(id: Int64, content: String, timestamp: Date, type: String) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.type = type
    }
}

@Observable
@MainActor
public final class ClipboardManager: ClipboardServiceProtocol {
    public var items: [ClipboardItem] = []

    private var db: Connection?
    private let clipboardTable = Table("clipboard")
    private let id = Expression<Int64>("id")
    private let content = Expression<String>("content")
    private let timestamp = Expression<Date>("timestamp")
    private let type = Expression<String>("type")

    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var timer: Timer?
    public private(set) var isMonitoring = false

    public init() {
        setupDatabase()
        fetchItems()
    }

    private func setupDatabase() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
            let appSupport = URL(fileURLWithPath: path).appendingPathComponent("machNotch", isDirectory: true)
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)

            db = try Connection(appSupport.appendingPathComponent("clipboard.sqlite3").path)

            try db?.run(
                clipboardTable.create(ifNotExists: true) { t in
                    t.column(id, primaryKey: .autoincrement)
                    t.column(content)
                    t.column(timestamp)
                    t.column(type)
                })
        } catch {
            print("ClipboardManager: Database setup failed: \(error)")
        }
    }

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkPasteboard() }
        }
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let str = pasteboard.string(forType: .string) {
            addItem(str, type: "text")
        }
    }

    private func addItem(_ str: String, type: String) {
        // Don't add if same as last item
        if let last = items.first, last.content == str { return }

        do {
            let insert = clipboardTable.insert(content <- str, timestamp <- Date(), self.type <- type)
            try db?.run(insert)
            fetchItems()
        } catch {
            print("ClipboardManager: Failed to add item: \(error)")
        }
    }

    public func fetchItems() {
        do {
            let query = clipboardTable.order(timestamp.desc).limit(50)
            let rows = try db?.prepare(query)

            self.items =
                rows?.map { row in
                    ClipboardItem(
                        id: row[self.id], content: row[self.id] == 0 ? "" : row[self.content],
                        timestamp: row[self.timestamp], type: row[self.type])
                } ?? []
        } catch {
            print("ClipboardManager: Failed to fetch items: \(error)")
        }
    }

    public func copyToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    public func deleteItem(_ item: ClipboardItem) {
        do {
            let target = clipboardTable.filter(id == item.id)
            try db?.run(target.delete())
            fetchItems()
        } catch {
            print("ClipboardManager: Failed to delete item: \(error)")
        }
    }

    public func clearHistory() {
        do {
            try db?.run(clipboardTable.delete())
            fetchItems()
        } catch {
            print("ClipboardManager: Failed to clear history: \(error)")
        }
    }
}
