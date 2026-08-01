import AppKit
import Foundation
import MachIntelligenceKit
import SwiftUI

struct ShelfView: View {
    @Environment(PluginUIContext.self) var uiContext
    @Environment(\.pluginManager) var pluginManager
    @Environment(ShelfSelectionModel.self) private var selection

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
    private var semanticEmbeddingService: (any AIEmbeddingService)? {
        guard let pluginManager else { return nil }
        return pluginManager.services.aiEmbedding
    }

    @State private var searchText = ""
    @State private var searchResults: [ShelfItem] = []
    @State private var searchErrorMessage: String?
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var searchService: ShelfSemanticSearchService?
    @FocusState private var isSearchFocused: Bool

    private let spacing: CGFloat = 8

    var body: some View {
        @Bindable var context = uiContext

        HStack(spacing: 12) {
            FileShareView()
                .aspectRatio(1, contentMode: .fit)
                .environment(uiContext)
            panel
                .onDrop(
                    of: [.fileURL, .url, .utf8PlainText, .plainText, .data],
                    isTargeted: Bindable(uiContext).dragDetectorTargeting
                ) { providers in
                    handleDrop(providers: providers)
                }
        }
        .onAppear {
            ensureSearchService()
        }
        // Bind Quick Look to shelf selection
        .onChange(of: shelfService.items) {
            searchService?.markNeedsRebuild()
            guard !normalizedSearchText.isEmpty else {
                searchResults = []
                return
            }
            performSearch(text: searchText)
        }
        .onChange(of: selection.selectedIDs) {
            updateQuickLookSelection()
        }
        .quickLookPresenter(using: quickLookService)
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayedItems: [ShelfItem] {
        normalizedSearchText.isEmpty ? shelfService.items : searchResults
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !selection.isDragging else { return false }
        uiContext.dropEvent = true
        shelfService.load(providers)
        return true
    }

    private func ensureSearchService() {
        guard searchService == nil, let embeddingService = semanticEmbeddingService else {
            return
        }
        searchService = ShelfSemanticSearchService(
            shelfService: shelfService,
            embeddingService: embeddingService
        )
    }

    private func performSearch(text: String) {
        searchTask?.cancel()

        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            searchResults = []
            searchErrorMessage = nil
            isSearching = false
            return
        }

        searchTask = Task {
            isSearching = true
            searchErrorMessage = nil

            if let service = searchService {
                let results = await service.search(normalized)
                if Task.isCancelled { return }

                searchResults = results
                isSearching = false
                if !service.supportsSemanticSearch {
                    searchErrorMessage = "Embedding search unavailable, showing local matches."
                }
                return
            }

            searchResults = localSearch(normalized, topK: 24)
            searchErrorMessage = "Embedding service unavailable, showing local matches."
            isSearching = false
        }
    }

    private func updateQuickLookSelection() {
        guard quickLookService.isQuickLookOpen && !selection.selectedIDs.isEmpty else { return }

        let selectedItems = selection.selectedItems(in: displayedItems)
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

    private func localSearch(_ query: String, topK: Int) -> [ShelfItem] {
        let normalized = query.lowercased()
        let matches = shelfService.items
            .compactMap { item -> (ShelfItem, Int)? in
                let haystack = ShelfSemanticSearchService.searchText(for: item).lowercased()
                guard haystack.contains(normalized) else { return nil }
                return (item, 1)
            }
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.displayName.localizedCaseInsensitiveCompare($1.0.displayName) == .orderedAscending
                }
                return $0.1 > $1.1
            }

        return Array(matches.prefix(topK).map { $0.0 })
    }

    var panel: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                uiContext.dragDetectorTargeting
                    ? Color.accentColor.opacity(0.9)
                    : Color.white.opacity(0.1),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10])
            )
            .overlay {
                content
                    .padding()
            }
            .transaction { transaction in
                transaction.animation = nil
            }
            .contentShape(Rectangle())
            .onTapGesture { selection.clear() }
    }

    var content: some View {
        Group {
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
                VStack(spacing: 12) {
                    searchBar

                    if let searchErrorMessage {
                        Text(searchErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if displayedItems.isEmpty && !normalizedSearchText.isEmpty {
                        VStack(spacing: 4) {
                            Text("No matches for “\(searchText)”")
                                .foregroundStyle(.secondary)
                            Text("Try a broader keyword.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: spacing) {
                                ForEach(displayedItems) { item in
                                    ShelfItemView(
                                        item: item, shelfService: shelfService, quickLookService: quickLookService,
                                        quickShareService: quickShareService
                                    )
                                    .environment(uiContext)
                                }
                            }
                        }
                        .padding(-spacing)
                        .scrollIndicators(.never)
                        .onDrop(
                            of: [.fileURL, .url, .utf8PlainText, .plainText, .data],
                            isTargeted: Bindable(uiContext).dragDetectorTargeting
                        ) { providers in
                            handleDrop(providers: providers)
                        }
                    }
                }
                .onAppear {
                    if !normalizedSearchText.isEmpty {
                        performSearch(text: searchText)
                    }
                }
            }
        }
        .onAppear {
            shelfService.cleanupInvalidItems()
        }
    }

    var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search shelf (⌘K)", text: $searchText)
                .focused($isSearchFocused)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, newValue in
                    performSearch(text: newValue)
                }
                .onSubmit {
                    performSearch(text: searchText)
                }

            if isSearching {
                ProgressView()
                    .controlSize(.small)
            }

            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }

            Button("Focus search") {
                isSearchFocused = true
            }
            .keyboardShortcut("k", modifiers: .command)
            .hidden()
        }
    }
}
