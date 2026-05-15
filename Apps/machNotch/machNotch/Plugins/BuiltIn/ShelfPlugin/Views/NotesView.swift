//
//  NotesView.swift
//  machNotch
//
//  Created by Alexander on 2025-12-29.
//

import SwiftUI

struct NotesView: View {
    var manager: any NotesServiceProtocol
    @State private var newNoteTitle = ""
    @State private var newNoteContent = ""
    @State private var isAdding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notes")
                    .font(.headline)
                Spacer()
                Button(action: { isAdding.toggle() }) {
                    Image(systemName: isAdding ? "xmark" : "plus")
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)

            if isAdding {
                VStack(spacing: 8) {
                    TextField("Title", text: $newNoteTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextEditor(text: $newNoteContent)
                        .frame(height: 60)
                        .cornerRadius(8)
                    Button("Add Note") {
                        manager.addNote(title: newNoteTitle, content: newNoteContent)
                        newNoteTitle = ""
                        newNoteContent = ""
                        isAdding = false
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
                .padding(.horizontal)
            }

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(manager.notes) { note in
                        NoteRow(note: note, manager: manager)
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NoteRow: View {
    let note: NoteItem
    var manager: any NotesServiceProtocol
    @State private var isHovering = false
    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var editContent = ""

    var body: some View {
        if isEditing {
            editingRow
        } else {
            displayRow
        }
    }

    private var displayRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(note.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                if isHovering {
                    HStack(spacing: 6) {
                        Button {
                            editTitle = note.title
                            editContent = note.content
                            isEditing = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Button {
                            manager.deleteNote(note)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            Text(note.content)
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.white.opacity(isHovering ? 0.1 : 0))
        .cornerRadius(8)
        .onHover { isHovering = $0 }
    }

    private var editingRow: some View {
        VStack(spacing: 6) {
            TextField("Title", text: $editTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.subheadline.bold())
            TextEditor(text: $editContent)
                .frame(height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .font(.caption)
            HStack {
                Button("Cancel") { isEditing = false }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Save") {
                    var updated = note
                    updated.title = editTitle
                    updated.content = editContent
                    manager.updateNote(updated)
                    isEditing = false
                }
                .buttonStyle(BorderedButtonStyle())
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}
