import Defaults
import Foundation
import SQLite

public struct NoteItem: Identifiable, Equatable, Sendable {
    public let id: Int64
    public var title: String
    public var content: String
    public let timestamp: Date

    public init(id: Int64, title: String, content: String, timestamp: Date) {
        self.id = id
        self.title = title
        self.content = content
        self.timestamp = timestamp
    }
}

@Observable
@MainActor
public final class NotesManager: NotesServiceProtocol {
    public var notes: [NoteItem] = []

    private static let obsidianSyncEnabledKey = Defaults.Key<Bool>("obsidianSyncEnabled", default: false)
    private static let obsidianVaultPathKey = Defaults.Key<String?>("obsidianVaultPath", default: nil)

    private var db: Connection?
    private let notesTable = Table("notes")
    private let id = Expression<Int64>("id")
    private let title = Expression<String>("title")
    private let content = Expression<String>("content")
    private let timestamp = Expression<Date>("timestamp")

    public init() {
        setupDatabase()
        fetchNotes()
    }

    private func setupDatabase() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
            let appSupport = URL(fileURLWithPath: path).appendingPathComponent("machNotch", isDirectory: true)
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)

            db = try Connection(appSupport.appendingPathComponent("notes.sqlite3").path)

            try db?.run(
                notesTable.create(ifNotExists: true) { t in
                    t.column(id, primaryKey: .autoincrement)
                    t.column(title)
                    t.column(content)
                    t.column(timestamp)
                })
        } catch {
            print("NotesManager: Database setup failed: \(error)")
        }
    }

    public func fetchNotes() {
        do {
            let query = notesTable.order(timestamp.desc)
            let rows = try db?.prepare(query)

            self.notes =
                rows?.map { row in
                    NoteItem(
                        id: row[self.id], title: row[self.title], content: row[self.content],
                        timestamp: row[self.timestamp])
                } ?? []
        } catch {
            print("NotesManager: Failed to fetch notes: \(error)")
        }
    }

    public func addNote(title: String, content: String) {
        do {
            let insert = notesTable.insert(self.title <- title, self.content <- content, timestamp <- Date())
            try db?.run(insert)
            fetchNotes()
            writeToObsidian(title: title, content: content)
        } catch {
            print("NotesManager: Failed to add note: \(error)")
        }
    }

    public func updateNote(_ note: NoteItem) {
        do {
            let target = notesTable.filter(id == note.id)
            try db?.run(target.update(title <- note.title, content <- note.content))
            fetchNotes()
            writeToObsidian(title: note.title, content: note.content)
        } catch {
            print("NotesManager: Failed to update note: \(error)")
        }
    }

    private func writeToObsidian(title: String, content: String) {
        guard Defaults[Self.obsidianSyncEnabledKey],
            let vaultPath = Defaults[Self.obsidianVaultPathKey],
            !vaultPath.isEmpty
        else { return }
        let vaultURL = URL(fileURLWithPath: vaultPath)
        let illegalChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let safeTitle = title.components(separatedBy: illegalChars).joined(separator: "-")
        let fileURL = vaultURL.appendingPathComponent("\(safeTitle).md")
        let markdown = "# \(title)\n\n\(content)\n"
        try? markdown.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    public func deleteNote(_ note: NoteItem) {
        do {
            let target = notesTable.filter(id == note.id)
            try db?.run(target.delete())
            fetchNotes()
        } catch {
            print("NotesManager: Failed to delete note: \(error)")
        }
    }
}
