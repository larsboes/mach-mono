//
//  NotesView.swift
//  boringNotch
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(note.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                if isHovering {
                    Button(action: { manager.deleteNote(note) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            Text(note.content)
                .font(.caption)
                .lineLimit(2)
        }
        .padding(8)
        .background(Color.white.opacity(isHovering ? 0.1 : 0))
        .cornerRadius(8)
        .onHover { isHovering = $0 }
    }
}
