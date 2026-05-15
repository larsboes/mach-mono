//
//  NotchPhaseCoordinator.swift
//  machNotch
//
//  Extracted open/close lifecycle and phase state machine.
//

import SwiftUI

@MainActor
protocol NotchPhaseDelegate: AnyObject {
    var hideOnClosedDebounceTask: Task<Void, Never>? { get set }
    var hoverController: NotchHoverController { get }
    var notchSize: CGSize { get set }
    var closedNotchSize: CGSize { get set }
    var shellAnimationProgress: CGFloat { get set }
    var contentRevealProgress: CGFloat { get set }
    var isBatteryPopoverActive: Bool { get set }
    var edgeAutoOpenActive: Bool { get set }
    var effectiveClosedNotchSize: CGSize { get }
    var displaySettings: any DisplaySettings { get }
    var screenUUID: String? { get }
    var currentView: NotchViews { get set }
    var settings: NotchViewModelSettings { get }
    var coordinator: any ViewCoordinating { get }
    var services: any NotchServiceProvider { get }
    var shelfService: ShelfServiceProtocol? { get }
    var isHoveringNotch: Bool { get }

    func syncWindowState()
    func handleHoverSignal(_ signal: HoverSignal)
    func syncAnimationState(animated: Bool)
    func syncBackgroundServices()
}

@MainActor
@Observable final class NotchPhaseCoordinator {
    weak var delegate: (any NotchPhaseDelegate)?

    private(set) var phase: NotchPhase = .closed {
        didSet {
            guard phase != oldValue else { return }
            delegate?.syncAnimationState(animated: true)
            delegate?.syncBackgroundServices()
        }
    }

    @ObservationIgnored var closeWatchdogTask: Task<Void, Never>?
    @ObservationIgnored var postCloseHoverTask: Task<Void, Never>?

    init() {}

    func open(initialVelocity: CGFloat = 0) {
        guard let delegate else { return }
        // Allow opening if closed OR if we are currently closing OR if we are scrubbing (opening)
        guard phase == .closed || phase == .closing || phase == .opening else { return }

        // Cancel stale tasks from a prior close cycle
        closeWatchdogTask?.cancel()
        closeWatchdogTask = nil
        postCloseHoverTask?.cancel()
        postCloseHoverTask = nil
        delegate.hideOnClosedDebounceTask?.cancel()
        delegate.hideOnClosedDebounceTask = nil

        delegate.hoverController.cancelPendingClose()

        // Shell expands — velocity determines spring character:
        // tap/keyboard (0) → confident settle, fast fling → playful overshoot
        let openAnimation =
            initialVelocity > 0
            ? StandardAnimations.openWithVelocity(initialVelocity)
            : StandardAnimations.open

        withAnimation(openAnimation) {
            delegate.notchSize = openNotchSize
            self.phase = .opening
            delegate.shellAnimationProgress = 1
        } completion: {
            guard self.phase == .opening, let delegate = self.delegate else { return }
            self.phase = .open
            delegate.hoverController.setNotchOpen(true)
            delegate.syncWindowState()
            delegate.hoverController.startHeartbeat()
        }

        // Content reveals independently — shell leads, content follows
        withAnimation(StandardAnimations.contentReveal) {
            delegate.contentRevealProgress = 1
        }

        delegate.services.music.forceUpdate()
    }

    func close(force: Bool = false) {
        guard let delegate else { return }
        if delegate.services.sharing.preventNotchClose { return }
        if !force && delegate.isHoveringNotch && phase == .open { return }
        // Allow closing if open OR if we are currently opening (interrupt).
        // Never re-enter close when already closing or closed — prevents double-close
        // animation conflicts even with force=true.
        guard phase == .open || phase == .opening else { return }

        delegate.hoverController.cancelPendingOpen()
        delegate.hoverController.setNotchOpen(false)
        delegate.hoverController.stopHeartbeat()

        // Reset transient state before animation starts
        delegate.isBatteryPopoverActive = false
        delegate.coordinator.sneakPeek.show = false
        delegate.edgeAutoOpenActive = false

        // Capture the target closed size BEFORE mutating phase.
        let targetClosedSize = delegate.effectiveClosedNotchSize
        // closedNotchSize is the BASE physical notch width (no ears).
        let baseClosedSize = getClosedNotchSize(settings: delegate.displaySettings, screenUUID: delegate.screenUUID)

        // Content and Shell exit together for a unified, clean contraction
        withAnimation(StandardAnimations.close) {
            delegate.contentRevealProgress = 0
            delegate.shellAnimationProgress = 0
            delegate.notchSize = targetClosedSize
            delegate.closedNotchSize = baseClosedSize
            self.phase = .closing
        } completion: {
            guard self.phase == .closing, let delegate = self.delegate else { return }
            self.phase = .closed
            delegate.syncWindowState()

            // Delay hover re-check to prevent immediate re-open.
            self.postCloseHoverTask?.cancel()
            self.postCloseHoverTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                guard let self, !Task.isCancelled, self.phase == .closed else { return }
                if self.delegate?.hoverController.isMouseInHoverZone() == true {
                    self.delegate?.handleHoverSignal(.entered)
                }
            }
        }

        // --- Safety Watchdog ---
        closeWatchdogTask?.cancel()
        closeWatchdogTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard let self, !Task.isCancelled else { return }
            if self.phase == .closing {
                self.phase = .closed
                self.delegate?.syncWindowState()
                self.delegate?.syncAnimationState(animated: false)
            }
        }

        // Restore default view
        let isShelfEmpty = delegate.shelfService?.isEmpty ?? true
        if !isShelfEmpty && delegate.settings.openShelfByDefault {
            delegate.currentView = .shelf
        } else if !delegate.coordinator.openLastTabByDefault {
            delegate.currentView = .home
        }
    }

    func closeHello() {
        delegate?.coordinator.helloAnimationRunning = false
        close()
    }

    func interactiveScrub(progress: CGFloat) {
        guard let delegate else { return }
        // Only allow scrub from closed
        guard phase == .closed || phase == .opening else { return }

        // Cancel any pending close behavior
        closeWatchdogTask?.cancel()
        closeWatchdogTask = nil
        postCloseHoverTask?.cancel()
        postCloseHoverTask = nil
        delegate.hideOnClosedDebounceTask?.cancel()
        delegate.hideOnClosedDebounceTask = nil
        delegate.hoverController.cancelPendingClose()

        self.phase = .opening

        // Start hover heartbeat if not already running
        delegate.hoverController.setNotchOpen(true)
        delegate.syncWindowState()
        delegate.hoverController.startHeartbeat()

        let closedSize = delegate.effectiveClosedNotchSize
        let openSize = openNotchSize

        // Smoothly interpolate size based on progress
        let targetWidth = closedSize.width + (openSize.width - closedSize.width) * progress
        let targetHeight = closedSize.height + (openSize.height - closedSize.height) * progress

        // Interactive animation for immediate tracking
        withAnimation(StandardAnimations.interactive) {
            delegate.notchSize = CGSize(width: targetWidth, height: targetHeight)
            delegate.shellAnimationProgress = progress
            delegate.contentRevealProgress = progress
        }

        if progress > 0 {
            delegate.services.music.forceUpdate()
        }
    }

    func cancelInteractiveScrub() {
        guard phase == .opening else { return }
        close()
    }
}
