//
//  NotesManager.swift
//  boringNotch
//
//  Created by Alexander on 2025-12-29.
//

import Foundation
import SQLite

struct NoteItem: Identifiable, Equatable {
    let id: Int64
    var title: String
    var content: String
    let timestamp: Date
}

@Observable
@MainActor
final class NotesManager {
    var notes: [NoteItem] = []

    private var db: Connection?
    private let notesTable = Table("notes")
    private let id = Expression<Int64>("id")
    private let title = Expression<String>("title")
    private let content = Expression<String>("content")
    private let timestamp = Expression<Date>("timestamp")

    init() {
        setupDatabase()
        fetchNotes()
    }
    
    private func setupDatabase() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
            let appSupport = URL(fileURLWithPath: path).appendingPathComponent("boringNotch", isDirectory: true)
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            
            db = try Connection(appSupport.appendingPathComponent("notes.sqlite3").path)
            
            try db?.run(notesTable.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(title)
                t.column(content)
                t.column(timestamp)
            })
        } catch {
            print("NotesManager: Database setup failed: \(error)")
        }
    }
    
    func fetchNotes() {
        do {
            let query = notesTable.order(timestamp.desc)
            let rows = try db?.prepare(query)

            self.notes = rows?.map { row in
                NoteItem(id: row[self.id], title: row[self.title], content: row[self.content], timestamp: row[self.timestamp])
            } ?? []
        } catch {
            print("NotesManager: Failed to fetch notes: \(error)")
        }
    }
    
    func addNote(title: String, content: String) {
        do {
            let insert = notesTable.insert(self.title <- title, self.content <- content, timestamp <- Date())
            try db?.run(insert)
            fetchNotes()
        } catch {
            print("NotesManager: Failed to add note: \(error)")
        }
    }
    
    func updateNote(_ note: NoteItem) {
        do {
            let target = notesTable.filter(id == note.id)
            try db?.run(target.update(title <- note.title, content <- note.content))
            fetchNotes()
        } catch {
            print("NotesManager: Failed to update note: \(error)")
        }
    }
    
    func deleteNote(_ note: NoteItem) {
        do {
            let target = notesTable.filter(id == note.id)
            try db?.run(target.delete())
            fetchNotes()
        } catch {
            print("NotesManager: Failed to delete note: \(error)")
        }
    }
}
