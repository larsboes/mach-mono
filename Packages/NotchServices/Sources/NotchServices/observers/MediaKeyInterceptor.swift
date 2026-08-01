//
//  MediaKeyInterceptor.swift
//  machNotch
//
//  Event-tap owner for media-key interception.
//

import AppKit
import ApplicationServices
import Foundation

private let kSystemDefinedEventType = CGEventType(rawValue: 14)!

@MainActor
public final class MediaKeyInterceptor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let settings: any HUDSettings
    private let xpcHelper: any XPCHelperServiceProtocol
    private let feedbackPlayer = BezelFeedbackPlayer()
    private lazy var router = MediaKeyActionRouter(
        volumeService: volumeService,
        brightnessService: brightnessService,
        keyboardBacklightService: keyboardBacklightService,
        eventBus: eventBus,
        settings: settings,
        playFeedbackSound: { [weak feedbackPlayer] in
            feedbackPlayer?.playIfEnabled()
        }
    )

    private let volumeService: any VolumeServiceProtocol
    private let brightnessService: any BrightnessServiceProtocol
    private let keyboardBacklightService: any KeyboardBacklightServiceProtocol
    private let eventBus: PluginEventBus

    public init(
        volumeService: any VolumeServiceProtocol,
        brightnessService: any BrightnessServiceProtocol,
        keyboardBacklightService: any KeyboardBacklightServiceProtocol,
        eventBus: PluginEventBus,
        settings: any HUDSettings,
        xpcHelper: any XPCHelperServiceProtocol
    ) {
        self.volumeService = volumeService
        self.brightnessService = brightnessService
        self.keyboardBacklightService = keyboardBacklightService
        self.eventBus = eventBus
        self.settings = settings
        self.xpcHelper = xpcHelper
    }

    public func requestAccessibilityAuthorization() {
        xpcHelper.requestAccessibilityAuthorization()
    }

    public func ensureAccessibilityAuthorization(promptIfNeeded: Bool = false) async -> Bool {
        await xpcHelper.ensureAccessibilityAuthorization(promptIfNeeded: promptIfNeeded)
    }

    public func start(promptIfNeeded: Bool = false) async {
        guard eventTap == nil else { return }
        guard settings.hudReplacement else {
            stop()
            return
        }
        guard await accessAllowed(promptIfNeeded: promptIfNeeded) else { return }

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << kSystemDefinedEventType.rawValue),
            callback: { _, _, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
                return interceptor.handle(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        guard let eventTap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    public func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
    }

    private func accessAllowed(promptIfNeeded: Bool) async -> Bool {
        if await xpcHelper.isAccessibilityAuthorized() {
            return true
        }
        guard promptIfNeeded else { return false }
        return await ensureAccessibilityAuthorization(promptIfNeeded: true)
    }

    private func handle(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        guard cgEvent.type != .null, let nsEvent = NSEvent(cgEvent: cgEvent) else {
            return Unmanaged.passUnretained(cgEvent)
        }
        guard let press = MediaKeyEventParser.press(from: nsEvent) else {
            return Unmanaged.passUnretained(cgEvent)
        }

        router.handle(press)
        return nil
    }
}
