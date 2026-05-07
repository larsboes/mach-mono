//
//  NotchContentRouter.swift
//  machNotch
//
//  Created as part of Phase 3 architectural refactoring.
//  Routes notch content based on NotchStateMachine state.
//  This will eventually replace the 120-line if-else chains in ContentView.
//

import SwiftUI

/// Routes notch content based on the current display state.
/// Uses NotchStateMachine to determine what content to show.
struct NotchContentRouter: View {
    let displayState: NotchDisplayState
    let albumArtNamespace: Namespace.ID

    // Required environment and state for rendering
    @Environment(NotchViewModel.self) var vm
    @Environment(\.pluginManager) var pluginManager
    @Environment(\.settings) var settings
    @Environment(NotchStateMachine.self) var stateMachine
    @Bindable var coordinator: NotchViewCoordinator

    /// Height to use for closed notch content
    var closedNotchHeight: CGFloat
    
    var cornerRadiusScaleFactor: CGFloat?
    var cornerRadiusInsets: CornerRadiusInsets

    var body: some View {
        Group {
            switch displayState {
            case .helloAnimation:
                helloAnimationContent

            case .closed(let content):
                closedContent(content)

            case .open(let view):
                openContent(view)

            case .sneakPeek:
                // Handled in closedContent for now, but enum allows top-level state
                EmptyView()

            case .expanding:
                // Expanding view content (future implementation)
                EmptyView()
            }
        }
        .environment(coordinator)
    .environment(\.displayClosedNotchHeight, closedNotchHeight)
    .environment(\.cornerRadiusScaleFactor, cornerRadiusScaleFactor)
    .environment(\.cornerRadiusInsets, cornerRadiusInsets)
    .environment(\.albumArtNamespace, albumArtNamespace)
    }

    // MARK: - Hello Animation

    @ViewBuilder
    private var helloAnimationContent: some View {
        Spacer()
        HelloAnimation(onFinish: {
            vm.closeHello()
        })
        .frame(width: getClosedNotchSize(settings: settings).width, height: 80)
        .padding(.top, 40)
        Spacer()
    }

    // MARK: - Closed Content

    @ViewBuilder
    private func closedContent(_ content: NotchDisplayState.ClosedContent) -> some View {
        switch content {
        case .idle:
            idleContent

        case .plugin(let id):
            if let pluginManager {
                pluginManager.closedNotchView(for: id)
                    .frame(height: closedNotchHeight)
            }

        case .face:
            NotchMoodView(spacing: vm.closedNotchSize.width + 10)
                .frame(height: closedNotchHeight)

        case .inlineHUD(let type, let value, let icon):
            inlineHUDContent(type: type, value: value, icon: icon)

        case .sneakPeek(let type, let value, let icon):
            sneakPeekOverlayContent(type: type, value: value, icon: icon)
        }
    }

    @ViewBuilder
    private var idleContent: some View {
        if let pluginManager, pluginManager.isPluginEnabled(id: PluginID.systemStats) {
            pluginManager.closedNotchView(for: PluginID.systemStats)
                .frame(height: closedNotchHeight)
        } else {
            Rectangle()
                .fill(Color.clear)
                .frame(width: vm.closedNotchSize.width, height: closedNotchHeight)
        }
    }

    @ViewBuilder
    private func inlineHUDContent(type: SneakContentType, value: CGFloat, icon: String) -> some View {
        InlineHUD(
            type: .constant(type),
            value: .constant(value),
            icon: .constant(icon),
            hoverAnimation: .constant(false),
            gestureProgress: .constant(0)
        )
        .transition(.opacity)
    }

    @ViewBuilder
    private func sneakPeekOverlayContent(type: SneakContentType, value: CGFloat, icon: String) -> some View {
        if type == .music && !vm.hideOnClosed && settings.sneakPeekStyles == .standard {
            HStack(alignment: .center) {
                Image(systemName: "music.note")
                GeometryReader { geo in
                    if let musicPlugin = pluginManager?.plugin(id: PluginID.music, as: MusicPlugin.self),
                       let track = musicPlugin.musicService?.currentTrack {
                        MarqueeText(
                            track.title + " - " + track.artist,
                            color: settings.playerColorTinting
                                ? Color(nsColor: musicPlugin.musicService?.avgColor ?? .gray).ensureMinimumBrightness(factor: 0.6)
                                : .gray,
                            delayDuration: 1.0,
                            frameWidth: geo.size.width
                        )
                    }
                }
            }
            .foregroundStyle(Color.gray)
            .padding(.bottom, 10)
        } else if type != .music && type != .battery {
            SystemEventIndicatorModifier(
                eventType: .constant(type),
                value: .constant(value),
                icon: .constant(icon),
                sendEventBack: { newVal in
                    guard let pluginManager else {
                        assertionFailure("NotchContentRouter: pluginManager not injected")
                        return
                    }
                    // Route HUD value changes through PluginEventBus instead of direct service access
                    pluginManager.eventBus.emit(
                        HUDValueChangeEvent(
                            sourcePluginId: PluginID.System.hud,
                            hudType: type,
                            newValue: newVal
                        )
                    )
                }
            )
            .padding(.bottom, 10)
            .padding(.leading, 4)
            .padding(.trailing, 8)
        }
    }

    // MARK: - Open Content

    @ViewBuilder
    private func openContent(_ view: NotchViews) -> some View {
        VStack(spacing: 12) {
            // Header should just clear the physical notch
            NotchHeader()
                .frame(height: max(
                    54, // Increased from 44 to prevent cutoff
                    (NSScreen.screen(withUUID: coordinator.selectedScreenUUID)?.safeAreaInsets.top
                        ?? NSScreen.main?.safeAreaInsets.top
                        ?? 0) + 10 // Add some breathing room
                ))

            // Content area with padding to avoid notch-edge clipping
            Group {
                switch view {
                case .home:
                    NotchHomeView(albumArtNamespace: albumArtNamespace)
                        .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity, alignment: .top)
                case .notes:
                    if let pluginManager {
                        NotesView(manager: pluginManager.services.notesManager)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                default:
                    if let pluginManager {
                        pluginManager.expandedPanelView(for: view.id)
                            .environment(vm) // Provide vm because Shelf uses it
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure content area is flexible
            .contentReveal(progress: vm.contentRevealProgress, staggerIndex: 2) // Unified transition for ALL plugins
            .padding(.horizontal, 32) // Match header padding (32) to stay inside rounded corners
            .padding(.bottom, 16)      // Bottom padding to avoid bottom-corner clipping
            .clipped()                 // Strict clipping at padding boundary
        }
        .clipped() // Ensure entire open content VStack is clipped at the island height boundary
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct NotchContentRouter_Previews: PreviewProvider {
    @Namespace static var namespace

    static var previews: some View {
        NotchContentRouter(
            displayState: NotchDisplayState.closed(content: NotchDisplayState.ClosedContent.idle),
            albumArtNamespace: namespace,
            coordinator: NotchViewCoordinator(settings: MockNotchSettings(), xpcHelper: XPCHelperClient.shared),
            closedNotchHeight: CGFloat(32),
            cornerRadiusScaleFactor: 1.0,
            cornerRadiusInsets: CornerRadiusInsets(opened: (top: 19, bottom: 24), closed: (top: 6, bottom: 14))
        )
    }
}
#endif
