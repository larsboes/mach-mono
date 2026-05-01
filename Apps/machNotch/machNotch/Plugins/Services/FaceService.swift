//
//  FaceService.swift
//  boringNotch
//
//  Created by Alexander on 2025-12-29.
//  Refactored by Agent on 2026-01-03.
//

import Foundation
import AppKit
import Observation

@MainActor
@Observable
final class FaceService: FaceServiceProtocol {
    // MARK: - Properties
    
    var eyeOffset: CGSize = .zero
    var isSleepy: Bool = false
    
    private var mouseMonitor: Any?
    private var idleTimer: Timer?
    private let idleThreshold: TimeInterval = 10.0
    private var settings: any MediaSettings

    // MARK: - Initialization

    init(settings: any MediaSettings) {
        self.settings = settings
        // Don't start monitoring immediately on init, wait for explicit call or use a lazy approach
        // But for now, to match previous behavior, we can start it.
        // Better pattern: Start when the service is initialized by the container.
        startMonitoring()
    }
    
    // MARK: - Methods
    
    func startMonitoring() {
        stopMonitoring() // Ensure no duplicates
        
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMove(event.locationInWindow)
            return event
        }
        
        resetIdleTimer()
    }
    
    func stopMonitoring() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        idleTimer?.invalidate()
        idleTimer = nil
    }
    
    private func handleMouseMove(_ location: NSPoint) {
        resetIdleTimer()
        
        // Calculate offset based on screen center
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let centerX = screenFrame.midX
        let centerY = screenFrame.midY
        
        let dx = (location.x - centerX) / (screenFrame.width / 2)
        let dy = (location.y - centerY) / (screenFrame.height / 2)
        
        // Limit offset to a small range
        // Since we are on MainActor, we can update directly
        self.eyeOffset = CGSize(width: dx * 2, height: -dy * 2)
        
        if self.isSleepy {
            self.isSleepy = false
            // Reset mood if it was sleepy
            if settings.selectedMood == .sleepy {
                settings.selectedMood = .neutral
            }
        }
    }
    
    private func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleThreshold, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isSleepy = true
            }
        }
    }
}
