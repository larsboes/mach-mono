//
//  BoringViewModel+Observers.swift
//  boringNotch
//
//  Observer setup, ears debounce, and sizing delegation.
//

import Combine
import Defaults
import SwiftUI

extension BoringViewModel {

    // MARK: - Observer Setup

    func setupDetectorObserver() {
        observerSetup.setupDetectorObserver(screenUUID: screenUUID) { [weak self] (shouldHide: Bool) in
            guard let self else { return }
            self.hideOnClosedDebounceTask?.cancel()
            self.hideOnClosedDebounceTask = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: .milliseconds(400))
                } catch { return }
                guard let self else { return }
                if self.hideOnClosed != shouldHide {
                    // Animate only when closed to avoid visual pop during open transitions
                    if self.notchState == .closed {
                        withAnimation(.smooth) {
                            self.hideOnClosed = shouldHide
                        }
                    } else {
                        self.hideOnClosed = shouldHide
                    }
                }
            }
        }
    }

    func setupBackgroundImageObserver() {
        observerSetup.setupBackgroundImageObserver { [weak self] image in
            self?.backgroundImage = image
        }
    }

    // MARK: - Ears Debounce

    func setupEarsObserver() {
        closedEarsActive = computeRawEarsActive()
        startEarsTracking()

        services.music.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.onEarsInputChanged() }
            .store(in: &earsCancellables)
    }

    private func startEarsTracking() {
        earsTrackingTask?.cancel()
        earsTrackingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let _ = withObservationTracking {
                    self.computeRawEarsActive()
                } onChange: { }

                self.onEarsInputChanged()

                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.computeRawEarsActive()
                    } onChange: {
                        continuation.resume()
                    }
                }
            }
        }
    }

    private func computeRawEarsActive() -> Bool {
        let isFaceActive = !services.music.playbackState.isPlaying &&
                           services.music.isPlayerIdle &&
                           settings.showNotHumanFace
        let isMusicActive = (services.music.playbackState.isPlaying || !services.music.isPlayerIdle) &&
                            settings.musicLiveActivityEnabled
        return (isMusicActive || isFaceActive) && !hideOnClosed
    }

    private func onEarsInputChanged() {
        let target = computeRawEarsActive()
        guard target != closedEarsActive else {
            earsDebounceTask?.cancel()
            earsDebounceTask = nil
            return
        }
        earsDebounceTask?.cancel()
        earsDebounceTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(400))
            } catch { return }
            guard let self, !Task.isCancelled else { return }
            let confirmed = self.computeRawEarsActive()
            if self.closedEarsActive != confirmed {
                self.closedEarsActive = confirmed
            }
        }
    }

    /// Reset currentView to .home when alwaysShowTabs is disabled and shelf isn't the default.
    func setupTabResetObserver() {
        Task { @MainActor [weak self] in
            for await value in Defaults.updates(.alwaysShowTabs) {
                guard let self, !value else { continue }
                let isShelfEmpty = self.shelfService?.isEmpty ?? true
                if isShelfEmpty || !self.settings.openShelfByDefault {
                    self.currentView = .home
                }
            }
        }
    }

    func setupNotchHeightObserver() {
        NotificationCenter.default.publisher(for: .notchHeightChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateNotchSize() }
            .store(in: &notificationCancellables)
    }

    func updateNotchSize() {
        let result = sizeCalculator.updateNotchSize(
            screenUUID: self.screenUUID,
            currentState: self.notchState
        )

        withAnimation(.smooth(duration: 0.3)) {
            if result.shouldUpdateNotchSize {
                self.notchSize = result.closedSize
            }

            if let screenFrame = getScreenFrame(self.screenUUID) {
                let width = openNotchSize.width
                let height = openNotchSize.height
                let x = screenFrame.midX - (width / 2)
                let y = screenFrame.maxY - height

                let region = CGRect(x: x, y: y, width: width, height: height)
                self.services.dragDrop.updateNotchRegion(region)
            }
        }
    }

    // MARK: - Sizing (delegation to calculator)

    /// Snapshot of all inputs the calculator needs.
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

    // MARK: - Intent Observers

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
