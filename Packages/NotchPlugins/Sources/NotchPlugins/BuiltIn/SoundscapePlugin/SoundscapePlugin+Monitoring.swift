//
//  SoundscapePlugin+Monitoring.swift
//  NotchPlugins
//
//  Event and system observers for adaptive soundscape behavior.
//

import Combine
import Foundation
import MachSoundKit
import NotchCore
import NotchServices

@MainActor
extension SoundscapePlugin {
    func setupEventSubscriptions() {
        guard let eventBus else { return }

        eventBus.subscribe(to: MusicPlaybackChangedEvent.self) { [weak self] event in
            guard let self else { return }
            self.handleMediaPlaybackChange(isPlaying: event.isPlaying)
        }.store(in: &cancellables)

        eventBus.subscribe(to: PomodoroPhaseChangedEvent.self) { [weak self] event in
            guard let self else { return }
            self.handlePomodoroChange(
                isRunning: event.isRunning,
                sessionType: event.sessionType,
                timeRemaining: event.timeRemaining
            )
        }.store(in: &cancellables)

        eventBus.subscribe(to: CalendarEventStartingSoonEvent.self) { [weak self] event in
            guard let self else { return }
            self.handleMeetingApproaching(startsIn: event.startsIn)
        }.store(in: &cancellables)
    }

    func setupSystemObservers() {
        DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.apple.screenIsLocked"))
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleScreenLockChange(locked: true)
                }
            }
            .store(in: &cancellables)

        DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.apple.screenIsUnlocked"))
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleScreenLockChange(locked: false)
                }
            }
            .store(in: &cancellables)
    }

    func startBackgroundMonitoring(_ soundEngine: SoundEngine) {
        activeTasks.append(
            Task {
                for await _ in soundEngine.beatEvents {
                    guard !Task.isCancelled else { break }
                    self.isBeatActive = true
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    self.isBeatActive = false
                }
            })

        activeTasks.append(
            Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    guard !Task.isCancelled else { break }

                    self.audioLevel = soundEngine.audioLevel
                    if self.isAdaptive {
                        self.updateContextState()
                    }
                }
            })
    }

    func handleMediaPlaybackChange(isPlaying: Bool) {
        guard isAdaptive, let engine else { return }
        if isPlaying {
            if self.isPlaying {
                wasPlayingBeforeDucking = true
                engine.pause()
            }
        } else if wasPlayingBeforeDucking && self.isPlaying {
            wasPlayingBeforeDucking = false
            engine.play()
        }
        updateContextState()
    }

    func handleScreenLockChange(locked: Bool) {
        guard let engine else { return }
        if locked, isPlaying {
            engine.pause()
        } else if !locked, isPlaying, !wasPlayingBeforeDucking {
            engine.play()
        }
    }
}
