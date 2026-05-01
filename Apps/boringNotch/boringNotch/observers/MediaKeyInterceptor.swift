//
//  MediaKeyInterceptor.swift
//  boringNotch
//
//  Created by Alexander on 2025-11-23.

import Foundation
import AppKit
import ApplicationServices
import AVFoundation

private let kSystemDefinedEventType = CGEventType(rawValue: 14)!

@MainActor
final class MediaKeyInterceptor {
    private enum NXKeyType: Int {
        case soundUp = 0
        case soundDown = 1
        case brightnessUp = 2
        case brightnessDown = 3
        case mute = 7
        case keyboardBrightnessUp = 21
        case keyboardBrightnessDown = 22
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let step: Float = 1.0 / 16.0
    private var audioPlayer: AVAudioPlayer?
    
    // Dependencies
    private let volumeService: any VolumeServiceProtocol
    private let brightnessService: any BrightnessServiceProtocol
    private let keyboardBacklightService: any KeyboardBacklightServiceProtocol
    private let eventBus: PluginEventBus
    private let settings: any HUDSettings
    private let xpcHelper: any XPCHelperServiceProtocol

    init(
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

    // MARK: - Accessibility (via XPC)

    func requestAccessibilityAuthorization() {
        xpcHelper.requestAccessibilityAuthorization()
    }

    func ensureAccessibilityAuthorization(promptIfNeeded: Bool = false) async -> Bool {
        await xpcHelper.ensureAccessibilityAuthorization(promptIfNeeded: promptIfNeeded)
    }

    // MARK: - Event Tap
    
    func start(promptIfNeeded: Bool = false) async {
        guard eventTap == nil else { return }

        // Ensure HUD replacement is enabled
        guard settings.hudReplacement else {
            stop()
            return
        }

        // Check accessibility authorization
        let authorized = await xpcHelper.isAccessibilityAuthorized()
        if !authorized {
            if promptIfNeeded {
                let granted = await ensureAccessibilityAuthorization(promptIfNeeded: true)
                guard granted else { return }
            } else {
                return
            }
        }

        let mask = CGEventMask(1 << kSystemDefinedEventType.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, cgEvent, userInfo in
                guard let userInfo else { return Unmanaged.passRetained(cgEvent) }
                let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
                return interceptor.handleEvent(cgEvent)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        
        if let eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            if let runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        runLoopSource = nil
        eventTap = nil
    }

    // MARK: - Event Handling

    private func handleEvent(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        // Ensure the CGEvent has a valid type before converting to NSEvent
        guard cgEvent.type != .null else {
            return Unmanaged.passUnretained(cgEvent)
        }

        guard let nsEvent = NSEvent(cgEvent: cgEvent),
              nsEvent.type == .systemDefined,
              nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(cgEvent)
        }

        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF_0000) >> 16
        let stateByte = ((data1 & 0xFF00) >> 8)

        // 0xA = key down, 0xB = key up. Only handle key down.
        guard stateByte == 0xA,
              let keyType = NXKeyType(rawValue: keyCode) else {
            return Unmanaged.passUnretained(cgEvent)
        }

        let flags = nsEvent.modifierFlags
        let option = flags.contains(.option)
        let shift = flags.contains(.shift)
        let command = flags.contains(.command)

        // Handle option key action (without shift)
        if option && !shift {
            if handleOptionAction(for: keyType, command: command) {
                return nil
            }
        }

        // Handle normal key press
        handleKeyPress(keyType: keyType, option: option, shift: shift, command: command)
        return nil
    }

    private func handleOptionAction(for keyType: NXKeyType, command: Bool) -> Bool {
        let action = settings.optionKeyAction

        switch action {
        case .openSettings:
            openSystemSettings(for: keyType, command: command)
            return true
        case .showHUD:
            showHUD(for: keyType, command: command)
            return true
        case .none:
            return true
        }
    }

    private func prepareAudioPlayerIfNeeded() {
        guard audioPlayer == nil else { return }

        let defaultPath = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
        if FileManager.default.fileExists(atPath: defaultPath) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: defaultPath))
                print("🔊 [MediaKeyInterceptor] Loaded default Bezel audio from: \(defaultPath)")
            } catch {
                print("⚠️ [MediaKeyInterceptor] Failed to init AVAudioPlayer with default path \(defaultPath): \(error.localizedDescription)")
            }
        } else {
            print("⚠️ [MediaKeyInterceptor] Default bezel audio not found at: \(defaultPath)")
        }

        if let player = audioPlayer {
            player.volume = 1.0
            player.numberOfLoops = 0
            player.prepareToPlay()
        }
    }

    private func playFeedbackSound() {
        guard let feedback = UserDefaults.standard.persistentDomain(forName: "NSGlobalDomain")?["com.apple.sound.beep.feedback"] as? Int,
              feedback == 1 else { return }

        prepareAudioPlayerIfNeeded()
        guard let player = audioPlayer else {
            print("⚠️ [MediaKeyInterceptor] No audio player available to play feedback sound")
            return
        }
        if let url = player.url {
            print("🔊 [MediaKeyInterceptor] Playing feedback sound from: \(url.path)")
        } else {
            print("🔊 [MediaKeyInterceptor] Playing feedback sound (no url available for AVAudioPlayer)")
        }
        if player.isPlaying {
            player.stop()
            player.currentTime = 0
        }
        player.play()
    }

    private func handleKeyPress(keyType: NXKeyType, option: Bool, shift: Bool, command: Bool) {
        let stepDivisor: Float = (option && shift) ? 4.0 : 1.0

        switch keyType {
        case .soundUp:
            self.playFeedbackSound()
            volumeService.increase(stepDivisor: stepDivisor)
        case .soundDown:
            self.playFeedbackSound()
            volumeService.decrease(stepDivisor: stepDivisor)
        case .mute:
            volumeService.toggleMuteAction()
        case .brightnessUp, .keyboardBrightnessUp:
            let delta = step / stepDivisor
            adjustBrightness(delta: delta, keyboard: keyType == .keyboardBrightnessUp || command)
        case .brightnessDown, .keyboardBrightnessDown:
            let delta = -(step / stepDivisor)
            adjustBrightness(delta: delta, keyboard: keyType == .keyboardBrightnessDown || command)
        }
    }

    private func adjustBrightness(delta: Float, keyboard: Bool) {
        if keyboard {
            keyboardBacklightService.setRelative(delta: delta)
        } else {
            brightnessService.setRelative(delta: delta)
        }
    }

    private func showHUD(for keyType: NXKeyType, command: Bool) {
        switch keyType {
        case .soundUp, .soundDown, .mute:
            let v = volumeService.rawVolume
            emitSneakPeek(type: .volume, value: CGFloat(v))
        case .brightnessUp, .brightnessDown:
            if command {
                let v = keyboardBacklightService.rawBrightness
                emitSneakPeek(type: .backlight, value: CGFloat(v))
            } else {
                let v = brightnessService.rawBrightness
                emitSneakPeek(type: .brightness, value: CGFloat(v))
            }
        case .keyboardBrightnessUp, .keyboardBrightnessDown:
            let v = keyboardBacklightService.rawBrightness
            emitSneakPeek(type: .backlight, value: CGFloat(v))
        }
    }

    private func emitSneakPeek(type: SneakContentType, value: CGFloat) {
        eventBus.emit(SneakPeekRequestedEvent(
            sourcePluginId: PluginID.System.mediaKeys,
            request: SneakPeekRequest(style: .standard, type: type, value: value)
        ))
    }

    private func openSystemSettings(for keyType: NXKeyType, command: Bool) {
        let urlString: String

        switch keyType {
        case .soundUp, .soundDown, .mute:
            urlString = "x-apple.systempreferences:com.apple.preference.sound"
        case .brightnessUp, .brightnessDown:
            if command {
                urlString = "x-apple.systempreferences:com.apple.preference.keyboard"
            } else {
                urlString = "x-apple.systempreferences:com.apple.preference.displays"
            }
        case .keyboardBrightnessUp, .keyboardBrightnessDown:
            urlString = "x-apple.systempreferences:com.apple.preference.keyboard"
        }

        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
