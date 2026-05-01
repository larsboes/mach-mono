//
//  ContentView.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan Goswami  on 02/08/24
//  Modified by Richard Kunkli on 24/08/2024.
//

import AVFoundation
import Combine
import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(BoringViewModel.self) var vm
    @Environment(\.pluginManager) var pluginManager
    @Environment(\.settings) var settings

    @Environment(BoringViewCoordinator.self) var coordinator
    @Environment(NotchStateMachine.self) var stateMachine
    @Environment(\.showSettingsWindow) var showSettingsWindow

    @State private var anyDropDebounceTask: Task<Void, Never>?

    @State var gestureProgress: CGFloat = .zero

    @State var haptics: Bool = false

    var musicService: any MusicServiceProtocol {
        vm.services.music
    }

    @Namespace var albumArtNamespace

    var isDisplayStateOpen: Bool {
        if case .open = stateMachine.displayState { return true }
        return false
    }

    // MARK: - State Observation

    private struct StateSnapshot: Equatable {
        let helloAnimationRunning: Bool
        let notchState: NotchState
        let currentView: NotchViews
        let sneakPeekShow: Bool
        let expandingViewShow: Bool
        let isPlaying: Bool
        let isPlayerIdle: Bool
        let activePluginId: String?
        let pluginActivationGeneration: Int
    }

    private var currentStateSnapshot: StateSnapshot {
        StateSnapshot(
            helloAnimationRunning: coordinator.helloAnimationRunning,
            notchState: vm.notchState,
            currentView: vm.currentView,
            sneakPeekShow: coordinator.sneakPeek.show,
            expandingViewShow: coordinator.expandingView.show,
            isPlaying: musicService.playbackState.isPlaying,
            isPlayerIdle: musicService.isPlayerIdle,
            activePluginId: pluginManager?.highestPriorityClosedNotchPlugin(),
            pluginActivationGeneration: pluginManager?.pluginActivationGeneration ?? 0
        )
    }

    var body: some View {
        @Bindable var vm = vm
        let _ = {
            if let pluginManager {
                vm.shelfService = pluginManager.services.shelf
            }
        }()
        
        // Calculate scale based on gesture progress only
        let gestureScale: CGFloat = {
            guard gestureProgress != 0 else { return 1.0 }
            let scaleFactor = 1.0 + gestureProgress * 0.01
            return max(0.6, scaleFactor)
        }()
        
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                NotchContentRouter(
                    displayState: stateMachine.displayState,
                    albumArtNamespace: albumArtNamespace,
                    coordinator: coordinator,
                    closedNotchHeight: displayClosedNotchHeight,
                    cornerRadiusScaleFactor: cornerRadiusScaleFactor,
                    cornerRadiusInsets: cornerRadiusInsets
                )
                    .environment(\.contentProgress, contentProgress)
                    .environment(\.isNotchClosing, vm.phase == .closing)
                    .onAppear {
                        updateStateMachine()
                    }
                    .onChange(of: currentStateSnapshot) { _, _ in updateStateMachine() }
                    .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], delegate: GeneralDropTargetDelegate(isTargeted: $vm.generalDropTargeting))
                    .frame(width: computedChinWidth, alignment: .top)
                    // Smooth width changes when closed (music ears, battery, face).
                    // nil during transitions — those are driven by withAnimation in open()/close().
                    .animation(vm.phase == .closed ? .smooth(duration: 0.3) : nil, value: computedChinWidth)
                    // Smoothly interpolate bottom padding based on animation progress
                    .padding(.bottom, lerp(0, 12, animationProgress))
                    .frame(height: isDisplayStateOpen ? vm.notchSize.height : nil, alignment: .top)
                    .clipped()
                    .clipShape(currentNotchShape)
                    .background { notchBackground }
                    .overlay { glassOverlay }
                    .background(alignment: .top) { ambientVisualizerOverlay }
                    // Single animation for phase transitions (animations handled in ViewModel)
                    // Keep gesture progress animation separate for responsive feedback
                    .animation(.smooth, value: gestureProgress)
                    .background {
                        TrackingAreaView { signal in
                            vm.handleHoverSignal(signal)
                        }
                    }
                    .panGesture(direction: .down, disabled: !settings.enableGestures || coordinator.isScrollableViewPresented) { translation, phase in
                        handleDownGesture(translation: translation, phase: phase)
                    }
                    .panGesture(direction: .up, disabled: !settings.closeGestureEnabled || !settings.enableGestures || coordinator.isScrollableViewPresented) { translation, phase in
                        handleUpGesture(translation: translation, phase: phase)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .sharingDidFinish)) { _ in
                        // Cancel any pending close when sharing finishes
                        if pluginManager?.services.sharing.preventNotchClose != true {
                            vm.cancelPendingClose()
                        }
                    }
                    .sensoryFeedback(.alignment, trigger: haptics)
                    .contextMenu {
                        Button("Settings") {
                            showSettingsWindow()
                        }
                        .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
                    }
                if vm.chinHeight > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.01))
                        .frame(width: computedChinWidth, height: vm.chinHeight)
                }
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: windowSize.width, maxHeight: windowSize.height, alignment: .top)

        .scaleEffect(
            x: gestureScale,
            y: gestureScale,
            anchor: .top
        )
        .animation(.smooth, value: gestureProgress)
        .background(dragDetector)
        .preferredColorScheme(.dark)
        .environment(vm)
        .onChange(of: vm.anyDropZoneTargeting) { _, isTargeted in
            anyDropDebounceTask?.cancel()

            if isTargeted {
                if vm.notchState == .closed {
                    vm.currentView = .shelf
                    doOpen()
                }
                return
            }

            anyDropDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }

                if vm.dropEvent {
                    vm.dropEvent = false
                    return
                }

                vm.dropEvent = false
                if pluginManager?.services.sharing.preventNotchClose != true {
                    vm.close()
                }
            }
        }
    }

    private func updateStateMachine() {
        // Sync plugin preferred height for notch sizing
        if let activePluginId = pluginManager?.highestPriorityClosedNotchPlugin(),
           let plugin = pluginManager?.plugin(id: activePluginId),
           let preferredHeight = plugin.displayRequest?.preferredHeight {
            vm.pluginPreferredHeight = preferredHeight
        } else {
            vm.pluginPreferredHeight = nil
        }

        let input = NotchStateMachine.createInput(
            notchState: vm.notchState,
            currentView: vm.currentView,
            coordinator: coordinator,
            musicService: musicService,
            pluginManager: pluginManager,
            hideOnClosed: vm.hideOnClosed,
            settings: settings
        )
        stateMachine.update(with: input)
    }

    @ViewBuilder
    var dragDetector: some View {
        @Bindable var vm = vm
        if settings.boringShelf && vm.notchState == .closed, let pluginManager {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
                    vm.dropEvent = true
                    pluginManager.services.shelf.load(providers)
                    return true
                }
        } else {
            EmptyView()
        }
    }

    func doOpen(velocity: CGFloat = 0) {
        vm.open(initialVelocity: velocity)
    }
}

#Preview {
    let vm = BoringViewModel()
    ContentView()
        .environment(vm)
        .environment(NotchStateMachine(settings: MockNotchSettings()))
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
        .onAppear {
            vm.open()
        }
}
