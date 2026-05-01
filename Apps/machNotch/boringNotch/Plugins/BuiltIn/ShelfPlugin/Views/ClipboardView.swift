//
//  ClipboardView.swift
//  boringNotch
//
//  Created by Alexander on 2025-12-29.
//

import SwiftUI

struct ClipboardView: View {
    var manager: any ClipboardServiceProtocol
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Clipboard")
                    .font(.headline)
                Spacer()
                Button(action: { manager.clearHistory() }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(manager.items) { item in
                        ClipboardRow(item: item, manager: manager)
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ClipboardRow: View {
    let item: ClipboardItem
    var manager: any ClipboardServiceProtocol
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            Text(item.content)
                .lineLimit(1)
                .font(.subheadline)
            Spacer()
            if isHovering {
                HStack(spacing: 8) {
                    Button(action: { manager.copyToPasteboard(item) }) {
                        Image(systemName: "doc.on.doc")
                    }
                    Button(action: { manager.deleteItem(item) }) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8)
        .background(Color.white.opacity(isHovering ? 0.1 : 0))
        .cornerRadius(8)
        .onHover { isHovering = $0 }
        .onTapGesture {
            manager.copyToPasteboard(item)
        }
    }
}
