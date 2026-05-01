//
//  ShelfItemView.swift
//  boringNotch
//
//  Created by Alexander on 2025-09-24.
//

import AppKit
import SwiftUI
import QuickLook

struct ShelfItemView: View {
    let item: ShelfItem
    let shelfService: ShelfServiceProtocol
    let quickLookService: any QuickLookServiceProtocol
    let quickShareService: QuickShareService
    @Environment(BoringViewModel.self) var vm
    @Environment(\.settings) var settings

    private var selection: ShelfSelectionModel {
        shelfService.selection
    }

    @State private var viewModel: ShelfItemViewModel
    @State private var showStack = false
    @State private var debouncedDropTarget = false

    private var isSelected: Bool { selection.isSelected(item.id) }
    private var shouldHideDuringDrag: Bool { selection.isDragging && selection.isSelected(item.id) && false }

    init(item: ShelfItem, shelfService: ShelfServiceProtocol, quickLookService: any QuickLookServiceProtocol, quickShareService: QuickShareService) {
        self.item = item
        self.shelfService = shelfService
        self.quickLookService = quickLookService
        self.quickShareService = quickShareService
        _viewModel = State(initialValue: ShelfItemViewModel(item: item))
    }

    var body: some View {
        ZStack {
            if !shouldHideDuringDrag {
                VStack(alignment: .center, spacing: 2) {
                    iconView
                    textView
                }
                .frame(width: 105)
                .padding(.vertical, 10)
                .padding(.horizontal, 5)
                .background(backgroundView)
                .contentShape(Rectangle())
                .animation(.easeInOut(duration: 0.1), value: debouncedDropTarget)
                .animation(.easeInOut(duration: 0.1), value: isSelected)

                DraggableClickHandler(
                    item: item,
                    settings: settings,
                    viewModel: viewModel,
                    service: shelfService,
                    dragPreviewContent: {
                        DragPreviewView(thumbnail: viewModel.thumbnail ?? item.icon, displayName: item.displayName)
                    },
                    onRightClick: { event, view in
                        viewModel.handleRightClick(event: event, view: view, service: shelfService, quickLookService: quickLookService, quickShareService: quickShareService)
                    },
                    onClick: { event, nsview in
                        viewModel.handleClick(event: event, view: nsview, items: shelfService.items, service: shelfService, quickLookService: quickLookService, quickShareService: quickShareService)
                    }
                )
            } else {
                Color.clear
                    .frame(width: 105)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 5)
            }
        }
        .onChange(of: viewModel.isDropTargeted) { _, targeted in
            vm.dragDetectorTargeting = targeted
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                debouncedDropTarget = targeted
            }
        }
        .onAppear {
            Task {
                await viewModel.loadThumbnail(service: shelfService)
            }
        }
    }

    // MARK: - View Components

    private var iconView: some View {
        Image(nsImage: viewModel.thumbnail ?? item.icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
    }

    private var textView: some View {
        Text(item.displayName)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .truncationMode(.middle)
            .multilineTextAlignment(.center)
            .frame(height: 30, alignment: .top)
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: strokeWidth)
            )
    }

    private var backgroundColor: Color {
        if debouncedDropTarget { return Color.accentColor.opacity(0.25) }
        if isSelected { return Color.accentColor.opacity(0.15) }
        return Color.clear
    }

    private var strokeColor: Color {
        if debouncedDropTarget { return Color.accentColor.opacity(0.9) }
        if isSelected { return Color.accentColor.opacity(0.8) }
        return Color.clear
    }

    private var strokeWidth: CGFloat {
        if debouncedDropTarget { return 3 }
        if isSelected { return 2 }
        return 1
    }
}
