//
//  MediaKeyActionRouter.swift
//  machNotch
//
//  Reauthored media-key action policy for MIT-readiness.
//

import AppKit
import Foundation

@MainActor
final class MediaKeyActionRouter {
    private let volumeService: any VolumeServiceProtocol
    private let brightnessService: any BrightnessServiceProtocol
    private let keyboardBacklightService: any KeyboardBacklightServiceProtocol
    private let eventBus: PluginEventBus
    private let settings: any HUDSettings
    private let playFeedbackSound: () -> Void
    private let openURL: (URL) -> Void
    private let baseStep: Float = 1.0 / 16.0

    init(
        volumeService: any VolumeServiceProtocol,
        brightnessService: any BrightnessServiceProtocol,
        keyboardBacklightService: any KeyboardBacklightServiceProtocol,
        eventBus: PluginEventBus,
        settings: any HUDSettings,
        playFeedbackSound: @escaping () -> Void,
        openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.volumeService = volumeService
        self.brightnessService = brightnessService
        self.keyboardBacklightService = keyboardBacklightService
        self.eventBus = eventBus
        self.settings = settings
        self.playFeedbackSound = playFeedbackSound
        self.openURL = openURL
    }

    func handle(_ press: MediaKeyPress) {
        if press.modifiers.option && !press.modifiers.shift {
            handleOptionKey(press)
            return
        }

        applySystemChange(for: press)
    }

    private func handleOptionKey(_ press: MediaKeyPress) {
        switch settings.optionKeyAction {
        case .openSettings:
            openSystemSettings(for: press)
        case .showHUD:
            showHUD(for: press)
        case .none:
            break
        }
    }

    private func applySystemChange(for press: MediaKeyPress) {
        switch press.kind {
        case .soundUp:
            playFeedbackSound()
            volumeService.increase(stepDivisor: stepDivisor(for: press))
        case .soundDown:
            playFeedbackSound()
            volumeService.decrease(stepDivisor: stepDivisor(for: press))
        case .mute:
            volumeService.toggleMuteAction()
        case .brightnessUp, .keyboardBrightnessUp:
            adjustBrightness(by: baseStep / stepDivisor(for: press), keyboard: press.targetsKeyboardBacklight)
        case .brightnessDown, .keyboardBrightnessDown:
            adjustBrightness(by: -(baseStep / stepDivisor(for: press)), keyboard: press.targetsKeyboardBacklight)
        }
    }

    private func stepDivisor(for press: MediaKeyPress) -> Float {
        press.usesFineStep ? 4 : 1
    }

    private func adjustBrightness(by delta: Float, keyboard: Bool) {
        if keyboard {
            keyboardBacklightService.setRelative(delta: delta)
        } else {
            brightnessService.setRelative(delta: delta)
        }
    }

    private func showHUD(for press: MediaKeyPress) {
        switch press.kind {
        case .soundUp, .soundDown, .mute:
            emitSneakPeek(type: .volume, value: CGFloat(volumeService.rawVolume))
        case .brightnessUp, .brightnessDown:
            if press.targetsKeyboardBacklight {
                emitSneakPeek(type: .backlight, value: CGFloat(keyboardBacklightService.rawBrightness))
            } else {
                emitSneakPeek(type: .brightness, value: CGFloat(brightnessService.rawBrightness))
            }
        case .keyboardBrightnessUp, .keyboardBrightnessDown:
            emitSneakPeek(type: .backlight, value: CGFloat(keyboardBacklightService.rawBrightness))
        }
    }

    private func emitSneakPeek(type: SneakContentType, value: CGFloat) {
        eventBus.emit(
            SneakPeekRequestedEvent(
                sourcePluginId: PluginID.System.mediaKeys,
                request: SneakPeekRequest(style: .standard, type: type, value: value)
            )
        )
    }

    private func openSystemSettings(for press: MediaKeyPress) {
        guard let url = URL(string: settingsURLString(for: press)) else { return }
        openURL(url)
    }

    private func settingsURLString(for press: MediaKeyPress) -> String {
        switch press.kind {
        case .soundUp, .soundDown, .mute:
            return "x-apple.systempreferences:com.apple.preference.sound"
        case .brightnessUp, .brightnessDown:
            return press.targetsKeyboardBacklight
                ? "x-apple.systempreferences:com.apple.preference.keyboard"
                : "x-apple.systempreferences:com.apple.preference.displays"
        case .keyboardBrightnessUp, .keyboardBrightnessDown:
            return "x-apple.systempreferences:com.apple.preference.keyboard"
        }
    }
}
