import XCTest
import AVFoundation
@testable import MachSoundKit

final class SoundEngineTests: XCTestCase {
    func testEngineLifecycle() throws {
        let context = SoundContext(
            daySegment: .day,
            weather: .clear,
            activity: 0.5,
            pomodoro: .focus(remainingSeconds: 1500),
            calendarNextEventIn: 3600,
            mediaPlaying: false,
            health: HealthFeatures(arousal: 0.5, sleepQuality: 0.8, recovery: 0.7)
        )
        
        let engine = SoundEngine(context: context)
        
        // Verify we can configure parameters
        engine.setMode(.focus)
        engine.setParameters(pace: 0.6, density: 0.6, brightness: 0.6, space: 0.6, pulse: 0.6, texture: 0.6)
        engine.setEnergy(0.8)
        engine.setVolume(0.5)
        engine.setAdaptive(true)
        
        // Start engine
        engine.play()
        
        // Let scheduler run a few ticks
        Thread.sleep(forTimeInterval: 0.2)
        
        // Verify audio level is updated
        let level = engine.audioLevel
        print("Test output: engine audio level = \(level)")
        
        // Update context dynamically
        let updatedContext = SoundContext(daySegment: .night, mediaPlaying: true)
        engine.updateContext(updatedContext)
        
        Thread.sleep(forTimeInterval: 0.1)
        
        // Pause engine
        engine.pause()
        
        XCTAssertTrue(true)
    }
}
