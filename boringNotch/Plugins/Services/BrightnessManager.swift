//  BrightnessManager.swift
//  boringNotch
//
//  Created by JeanLouis on 08/22/24.

import AppKit

@MainActor
@Observable final class BrightnessManager: BrightnessServiceProtocol {
	var rawBrightness: Float = 0
	var animatedBrightness: Float = 0
	var lastChangeAt: Date = .distantPast

	private let visibleDuration: TimeInterval = 1.2
	private let client: any XPCHelperServiceProtocol
	private let eventBus: PluginEventBus

	init(eventBus: PluginEventBus, xpcHelper: any XPCHelperServiceProtocol) {
		self.eventBus = eventBus
		self.client = xpcHelper
		refresh()
	}

	var shouldShowOverlay: Bool { Date().timeIntervalSince(lastChangeAt) < visibleDuration }

	func refresh() {
		Task {
			if let current = await client.currentScreenBrightness() {
				publish(brightness: current, touchDate: false)
			}
		}
	}

	func setRelative(delta: Float) {
		Task {
			let starting = await client.currentScreenBrightness() ?? rawBrightness
			let target = max(0, min(1, starting + delta))
			let ok = await client.setScreenBrightness(target)
			if ok {
				publish(brightness: target, touchDate: true)
			} else {
				refresh()
			}
			eventBus.emit(SneakPeekRequestedEvent(
			sourcePluginId: PluginID.System.brightness,
			request: SneakPeekRequest(style: .standard, type: .brightness, value: CGFloat(target))
		))
		}
	}

	func setAbsolute(value: Float) {
		let clamped = max(0, min(1, value))
		Task {
			let ok = await client.setScreenBrightness(clamped)
			if ok {
				publish(brightness: clamped, touchDate: true)
			} else {
				refresh()
			}
		}
	}

	private func publish(brightness: Float, touchDate: Bool) {
		if self.rawBrightness != brightness || touchDate {
			if touchDate { self.lastChangeAt = Date() }
			self.rawBrightness = brightness
			self.animatedBrightness = brightness
		}
	}
}

// (DisplayServices helpers moved into XPC helper)

// MARK: - Keyboard Backlight Controller
@MainActor
@Observable final class KeyboardBacklightManager: KeyboardBacklightServiceProtocol {
	var rawBrightness: Float = 0
	var lastChangeAt: Date = .distantPast

	private let visibleDuration: TimeInterval = 1.2
	private let client: any XPCHelperServiceProtocol
	private let eventBus: PluginEventBus

	init(eventBus: PluginEventBus, xpcHelper: any XPCHelperServiceProtocol) {
		self.eventBus = eventBus
		self.client = xpcHelper
		refresh()
	}

	var shouldShowOverlay: Bool { Date().timeIntervalSince(lastChangeAt) < visibleDuration }

	func refresh() {
		Task {
			if let current = await client.currentKeyboardBrightness() {
				publish(brightness: current, touchDate: false)
			}
		}
	}

	func setRelative(delta: Float) {
		Task {
			let starting = await client.currentKeyboardBrightness() ?? rawBrightness
			let target = max(0, min(1, starting + delta))
			let ok = await client.setKeyboardBrightness(target)
			if ok {
				publish(brightness: target, touchDate: true)
			} else {
				refresh()
			}
			eventBus.emit(SneakPeekRequestedEvent(
				sourcePluginId: PluginID.System.backlight,
				request: SneakPeekRequest(style: .standard, type: .backlight, value: CGFloat(target))
			))
		}
	}

	func setAbsolute(value: Float) {
		let clamped = max(0, min(1, value))
		Task {
			let ok = await client.setKeyboardBrightness(clamped)
			if ok {
				publish(brightness: clamped, touchDate: true)
			} else {
				refresh()
			}
		}
	}

	private func publish(brightness: Float, touchDate: Bool) {
		if self.rawBrightness != brightness || touchDate {
			if touchDate { self.lastChangeAt = Date() }
			self.rawBrightness = brightness
		}
	}
}
