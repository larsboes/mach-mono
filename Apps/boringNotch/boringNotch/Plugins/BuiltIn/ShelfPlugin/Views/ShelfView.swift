//
//  ShelfItemView.swift
//  boringNotch
//
//  Created by Alexander on 2025-09-24.
//

import SwiftUI
import AppKit

struct ShelfView: View {
    @Environment(BoringViewModel.self) var vm
    @Environment(\.pluginManager) var pluginManager
    
    private var selection: ShelfSelectionModel {
        pluginManager?.services.shelf.selection ?? ShelfSelectionModel()
    }
    
    private var quickLookService: any QuickLookServiceProtocol {
        guard let pluginManager else { preconditionFailure("pluginManager required") }
        return pluginManager.services.quickLook
    }
    private var quickShareService: QuickShareService {
        guard let pluginManager else { preconditionFailure("pluginManager required") }
        return pluginManager.services.quickShare
    }
    private var shelfService: any ShelfServiceProtocol {
        guard let pluginManager else { preconditionFailure("pluginManager required") }
        return pluginManager.services.shelf
    }
    private let spacing: CGFloat = 8

    var body: some View {
        @Bindable var vm = vm
        
        HStack(spacing: 12) {
            FileShareView()
                .aspectRatio(1, contentMode: .fit)
                .environment(vm)
            panel
                .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
                    handleDrop(providers: providers)
                }
        }
        // Bind Quick Look to shelf selection
        .onChange(of: selection.selectedIDs) {
            updateQuickLookSelection()
        }
        .quickLookPresenter(using: quickLookService)
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !selection.isDragging else { return false }
        vm.dropEvent = true
        shelfService.load(providers)
        return true
    }
    
    private func updateQuickLookSelection() {
        guard quickLookService.isQuickLookOpen && !selection.selectedIDs.isEmpty else { return }
        
        let selectedItems = selection.selectedItems(in: shelfService.items)
        let urls: [URL] = selectedItems.compactMap { item in
            if let fileURL = item.fileURL {
                return fileURL
            }
            if case .link(let url) = item.kind {
                return url
            }
            return nil
        }
        
        if !urls.isEmpty {
            quickLookService.updateSelection(urls: urls)
        }
    }

    var panel: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                vm.dragDetectorTargeting
                    ? Color.accentColor.opacity(0.9)
                    : Color.white.opacity(0.1),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10])
            )
            .overlay {
                content
                    .padding()
            }
            .transaction { transaction in
                transaction.animation = vm.animation
            }
            .contentShape(Rectangle())
            .onTapGesture { selection.clear() }
    }

    var content: some View {
        @Bindable var vm = vm
        return Group {
            if shelfService.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down")
                        .symbolVariant(.fill)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white, .gray)
                        .imageScale(.large)
                    
                    Text("Drop files here")
                        .foregroundStyle(.gray)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.medium)
                }
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: spacing) {
                        ForEach(shelfService.items) { item in
                            ShelfItemView(item: item, shelfService: shelfService, quickLookService: quickLookService, quickShareService: quickShareService)
                                .environment(vm)
                        }
                    }
                }
                .padding(-spacing)
                .scrollIndicators(.never)
                .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
                    handleDrop(providers: providers)
                }
            }
        }
        .onAppear {
            shelfService.cleanupInvalidItems()
        }
    }
}
