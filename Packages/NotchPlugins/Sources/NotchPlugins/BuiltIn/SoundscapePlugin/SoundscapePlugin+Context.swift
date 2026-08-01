//
//  SoundscapePlugin+Context.swift
//  NotchPlugins
//
//  Context adaptation for generative soundscapes.
//

import CoreGraphics
import Foundation
import MachSoundKit
import NotchCore
import NotchServices

@MainActor
extension SoundscapePlugin {
    func makeCurrentContext() -> SoundContext {
        SoundContext(
            daySegment: currentDaySegment(),
            weather: currentWeatherKind(),
            activity: currentActivityLevel(),
            pomodoro: currentPomodoroPhase,
            calendarNextEventIn: nextCalendarEventInterval(),
            mediaPlaying: wasPlayingBeforeDucking,
            health: nil
        )
    }

    func updateContextState() {
        guard let engine else { return }
        engine.updateContext(makeCurrentContext())
    }

    func handlePomodoroChange(isRunning: Bool, sessionType: String, timeRemaining: TimeInterval) {
        guard isAdaptive else { return }

        if isRunning {
            if sessionType == "Work" {
                currentPomodoroPhase = .focus(remainingSeconds: timeRemaining)
                updateMode(.focus)
            } else {
                currentPomodoroPhase = .break(remainingSeconds: timeRemaining)
                updateMode(.relax)
            }
        } else {
            currentPomodoroPhase = .none
        }
        updateContextState()
    }

    func handleMeetingApproaching(startsIn: TimeInterval) {
        guard isAdaptive, isPlaying, let engine else { return }
        if startsIn < 300 {
            engine.setVolume(volume * startsIn / 300.0)
        }
        updateContextState()
    }

    private func currentDaySegment() -> DaySegment {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 8 { return .dawn }
        if hour >= 8 && hour < 18 { return .day }
        if hour >= 18 && hour < 21 { return .dusk }
        return .night
    }

    private func currentWeatherKind() -> WeatherKind? {
        guard let condition = weatherService?.currentWeather?.condition.lowercased() else { return nil }
        if condition.contains("rain") || condition.contains("drizzle") { return .rainy }
        if condition.contains("cloud") || condition.contains("overcast") { return .cloudy }
        if condition.contains("wind") || condition.contains("breeze") { return .windy }
        if condition.contains("snow") || condition.contains("ice") || condition.contains("hail") { return .snowy }
        if condition.contains("clear") || condition.contains("sun") { return .clear }
        return .unknown
    }

    private func currentActivityLevel() -> Double {
        let anyEvent = CGEventType(rawValue: UInt32.max) ?? .null
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyEvent)
        return max(0.0, min(1.0, 1.0 - idle / 600.0))
    }

    private func nextCalendarEventInterval() -> TimeInterval? {
        guard let calendarService else { return nil }
        let now = Date()
        return calendarService.events
            .filter { !$0.type.isReminder && $0.start > now }
            .sorted { $0.start < $1.start }
            .first?
            .start
            .timeIntervalSince(now)
    }
}
