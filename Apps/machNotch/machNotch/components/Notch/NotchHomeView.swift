//
//  NotchHomeView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-18.
//  Modified by Harsh Vardhan Goswami & Richard Kunkli & Mustafa Ramadan & Arsh Anwar
//

import Defaults
import SwiftUI

// MARK: - Main View

struct NotchHomeView: View {
    @Environment(BoringViewModel.self) var vm
    @Environment(\.settings) var settings
    @Environment(\.pluginManager) var pluginManager
    @Environment(BoringViewCoordinator.self) var coordinator
    @Environment(\.contentProgress) var contentProgress
    let albumArtNamespace: Namespace.ID

    var body: some View {
        mainContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 4)
            .transition(.opacity)
            .environment(\.albumArtNamespace, albumArtNamespace) // Inject namespace for plugins
    }

    private var shouldShowCamera: Bool {
        settings.showMirror
            && (pluginManager?.services.webcam.cameraAvailable ?? false)
            && vm.isCameraExpanded
    }
    
    private var shouldShowCalendar: Bool {
        settings.showCalendar
    }
    
    private var additionalItemsCount: Int {
        var count = 0
        if shouldShowCalendar { count += 1 }
        if shouldShowCamera { count += 1 }
        return count
    }
    
    private var itemWidth: CGFloat {
        // Space reserved for the music player + controls
        let musicPlayerReservedWidth: CGFloat = 330
        // Calculate max width for side-plugins before overflowing the 860 total width
        let maxAvailableWidth: CGFloat = 860 - 64 - musicPlayerReservedWidth // 860 width, 64 total padding (32 each side)
        if additionalItemsCount == 0 { return maxAvailableWidth }
        
        // Base width, clamped to ensure it doesn't get too small or too large
        let calculatedWidth = maxAvailableWidth / CGFloat(additionalItemsCount)
        return min(max(calculatedWidth - 10, 80), 300)
    }

    private var mainContent: some View {
        HStack(alignment: .top, spacing: additionalItemsCount >= 2 ? 10 : 15) {
            // Render Music Plugin
            if let pluginManager {
                pluginManager.expandedPanelView(for: PluginID.music)
                    .contentReveal(progress: contentProgress, staggerIndex: 0)
            }

            if shouldShowCalendar {
                if let pluginManager {
                    pluginManager.expandedPanelView(for: PluginID.calendar)
                        .frame(width: itemWidth)
                        .clipped()
                        .onHover { isHovering in
                            vm.isHoveringCalendar = isHovering
                        }
                        .environment(vm)
                        .contentReveal(progress: contentProgress, staggerIndex: 1)
                }
            }

            if shouldShowCamera {
                if let pluginManager {
                    pluginManager.expandedPanelView(for: PluginID.webcam)
                        .scaledToFit()
                        .contentReveal(progress: contentProgress, staggerIndex: 2, useBlur: false)
                }
            }
        }
        .padding(.horizontal, 32)
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
    }
}
