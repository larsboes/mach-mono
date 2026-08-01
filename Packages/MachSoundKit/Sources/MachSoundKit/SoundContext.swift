import Foundation

public enum DaySegment: String, Sendable, Codable, CaseIterable {
    case dawn
    case day
    case dusk
    case night
}

public enum WeatherKind: String, Sendable, Codable, CaseIterable {
    case clear
    case cloudy
    case rainy
    case windy
    case snowy
    case unknown
}

public enum PomodoroPhase: Sendable, Codable, Equatable {
    case focus(remainingSeconds: TimeInterval)
    case `break`(remainingSeconds: TimeInterval)
    case none
}

public struct HealthFeatures: Sendable, Codable, Equatable {
    public var arousal: Double // 0-1
    public var sleepQuality: Double // 0-1
    public var recovery: Double // 0-1
    
    public init(arousal: Double, sleepQuality: Double, recovery: Double) {
        self.arousal = arousal
        self.sleepQuality = sleepQuality
        self.recovery = recovery
    }
}

public struct SoundContext: Sendable, Codable, Equatable {
    public var daySegment: DaySegment
    public var weather: WeatherKind?
    public var activity: Double // 0-1
    public var pomodoro: PomodoroPhase?
    public var calendarNextEventIn: TimeInterval?
    public var mediaPlaying: Bool
    public var health: HealthFeatures?
    
    public init(
        daySegment: DaySegment = .day,
        weather: WeatherKind? = nil,
        activity: Double = 0.5,
        pomodoro: PomodoroPhase? = nil,
        calendarNextEventIn: TimeInterval? = nil,
        mediaPlaying: Bool = false,
        health: HealthFeatures? = nil
    ) {
        self.daySegment = daySegment
        self.weather = weather
        self.activity = activity
        self.pomodoro = pomodoro
        self.calendarNextEventIn = calendarNextEventIn
        self.mediaPlaying = mediaPlaying
        self.health = health
    }
}

public enum BeatEvent: Sendable, Equatable {
    case kick
    case note(midi: Int)
    case bass(midi: Int)
    case chord(rootMidi: Int)
}

public enum SoundMode: String, Sendable, Codable, CaseIterable {
    case edm
    case ambient
    case lofi
    case focus
    case relax
    case sleep
}
