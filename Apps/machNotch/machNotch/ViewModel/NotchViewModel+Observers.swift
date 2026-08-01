//
//  NotchViewModel+Observers.swift
//  machNotch — mach-mono
//
//  Fullscreen hide debounce, closed-notch “ears” tracking, sizing, and automation intents.
//

import Combine
import Defaults
import SwiftUI

// MARK: - Debounce intervals (must stay aligned across fullscreen + ears paths)

private enum NotchObserverDebouncing {
    static let fullscreenHide = Duration.milliseconds(400)
    static let earsWidthSettle = Duration.milliseconds(400)
}

extension NotchViewModel {

    // MARK: - Fullscreen → hide when closed

    func setupDetectorObserver() {
        observerSetup.setupDetectorObserver(screenUUID: screenUUID) { [weak self] shouldHide in
            guard let self else { return }
            hideOnClosedDebounceTask?.cancel()
            hideOnClosedDebounceTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: NotchObserverDebouncing.fullscreenHide)
                guard let self, !Task.isCancelled else { return }
                guard hideOnClosed != shouldHide else { return }

                if notchState == .closed {
                    withAnimation(.smooth) {
                        self.hideOnClosed = shouldHide
                    }
                } else {
                    hideOnClosed = shouldHide
                }
            }
        }
    }

    func setupBackgroundImageObserver() {
        observerSetup.setupBackgroundImageObserver { [weak self] image in
            self?.backgroundImage = image
        }
    }

    // MARK: - Closed notch ears (debounced)

    func setupEarsObserver() {
        closedEarsActive = earsShouldShowForCurrentMediaState()
        beginClosedEarsObservationLoop()

        services.music.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.debounceClosedEarsUpdate() }
            .store(in: &earsCancellables)
    }

    /// Tracks Defaults / music-derived inputs that affect ear width without Combine publishers.
    private func beginClosedEarsObservationLoop() {
        earsTrackingTask?.cancel()
        earsTrackingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { break }

                debounceClosedEarsUpdate()

                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.earsShouldShowForCurrentMediaState()
                    } onChange: {
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// Raw ears eligibility before debounce (matches prior `computeRawEarsActive` semantics).
    private func earsShouldShowForCurrentMediaState() -> Bool {
        let playback = services.music.playbackState
        let idlePortraitEligible =
            !playback.isPlaying && services.music.isPlayerIdle && settings.showNotHumanFace
        let liveActivityEligible =
            (playback.isPlaying || !services.music.isPlayerIdle) && settings.musicLiveActivityEnabled
        return (idlePortraitEligible || liveActivityEligible) && !hideOnClosed
    }

    private func debounceClosedEarsUpdate() {
        let next = earsShouldShowForCurrentMediaState()
        guard next != closedEarsActive else {
            earsDebounceTask?.cancel()
            earsDebounceTask = nil
            return
        }

        earsDebounceTask?.cancel()
        earsDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: NotchObserverDebouncing.earsWidthSettle)
            guard let self, !Task.isCancelled else { return }
            let confirmed = earsShouldShowForCurrentMediaState()
            if closedEarsActive != confirmed {
                closedEarsActive = confirmed
            }
        }
    }

    // MARK: - Tabs

    func setupTabResetObserver() {
        Task { @MainActor [weak self] in
            for await value in Defaults.updates(DefaultsNotchSettings.alwaysShowTabsKey) {
                guard let self, !value else { continue }
                let shelfEmpty = shelfService?.isEmpty ?? true
                if shelfEmpty || !settings.openShelfByDefault {
                    currentView = .home
                }
            }
        }
    }

    func setupSizeObserver() {
        sizeObserverTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                    withObservationTracking {
                        _ = self?.displaySettings.notchHeight
                        _ = self?.displaySettings.notchHeightMode
                        _ = self?.displaySettings.nonNotchHeight
                        _ = self?.displaySettings.nonNotchHeightMode
                        _ = self?.displaySettings.inactiveNotchHeight
                        _ = self?.displaySettings.useInactiveNotchHeight
                    } onChange: {
                        c.resume()
                    }
                }
                guard let self, !Task.isCancelled else { return }
                self.updateNotchSize()
            }
        }
    }

    func updateNotchSize() {
        let delta = sizeCalculator.updateNotchSize(
            screenUUID: screenUUID,
            currentState: notchState
        )

        withAnimation(.smooth(duration: 0.3)) {
            if delta.shouldUpdateNotchSize {
                notchSize = delta.closedSize
            }

            if let screenFrame = getScreenFrame(screenUUID) {
                let w = openNotchSize.width
                let h = openNotchSize.height
                let rect = CGRect(
                    x: screenFrame.midX - w / 2,
                    y: screenFrame.maxY - h,
                    width: w,
                    height: h
                )
                services.dragDrop.updateNotchRegion(rect)
            }
        }
    }

    // MARK: - Closed-notch sizing inputs

    var closedNotchInput: ClosedNotchInput {
        ClosedNotchInput(
            screenUUID: screenUUID,
            hideOnClosed: hideOnClosed,
            sneakPeekActive: coordinator.sneakPeek.show,
            expandingViewActive: coordinator.expandingView.show,
            expandingViewType: coordinator.expandingView.type,
            pluginPreferredHeight: pluginPreferredHeight,
            closedEarsActive: closedEarsActive,
            showPowerStatusNotifications: settings.showPowerStatusNotifications,
            isMusicPlaying: services.music.playbackState.isPlaying,
            isPlayerIdle: services.music.isPlayerIdle,
            showNotHumanFace: settings.showNotHumanFace,
            phase: phase
        )
    }

    var effectiveClosedNotchHeight: CGFloat {
        sizeCalculator.effectiveClosedNotchHeight(input: closedNotchInput)
    }

    var effectiveClosedNotchSize: CGSize {
        sizeCalculator.effectiveClosedNotchSize(input: closedNotchInput)
    }

    var chinHeight: CGFloat {
        sizeCalculator.chinHeight(input: closedNotchInput, notchState: notchState)
    }

    // MARK: - App Intents / NotificationCenter bridge

    func setupIntentObservers() {
        NotificationCenter.default.publisher(for: .openNotchIntent)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.open() }
            .store(in: &notificationCancellables)

        NotificationCenter.default.publisher(for: .closeNotchIntent)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.close(force: true) }
            .store(in: &notificationCancellables)

        NotificationCenter.default.publisher(for: .toggleNotchIntent)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if notchState == .open {
                    close(force: true)
                } else {
                    open()
                }
            }
            .store(in: &notificationCancellables)

        NotificationCenter.default.publisher(for: .toggleMusicPlaybackIntent)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.services.music.togglePlayPause() }
            }
            .store(in: &notificationCancellables)

        NotificationCenter.default.publisher(for: .nextTrackIntent)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.services.music.next() }
            }
            .store(in: &notificationCancellables)

        NotificationCenter.default.publisher(for: .previousTrackIntent)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.services.music.previous() }
            }
            .store(in: &notificationCancellables)
    }
}
