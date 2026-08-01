//
//  SharingStateManager.swift
//  machNotch
//
//  Created by Alexander on 2025-10-10.
//

import AppKit
import Foundation

@MainActor
@Observable
public final class SharingStateManager: SharingServiceProtocol {
    private var activeSessions: Int = 0 {
        didSet {
            let newValue = activeSessions > 0
            if newValue != preventNotchClose {
                preventNotchClose = newValue
                if !newValue {
                    NotificationCenter.default.post(name: .sharingDidFinish, object: nil)
                }
            }
        }
    }

    public var preventNotchClose: Bool = false

    private var activeDelegates: [UUID: SharingLifecycleDelegate] = [:]

    public init() {}

    public func requestCloseIfReady() {
        if !preventNotchClose {
            NotificationCenter.default.post(name: .sharingDidFinish, object: nil)
        }
    }

    public func beginInteraction() {
        activeSessions += 1
    }

    public func endInteraction() {
        if activeSessions > 0 { activeSessions -= 1 }
    }

    public func makeDelegate(onEnd: (() -> Void)? = nil) -> SharingLifecycleDelegate {
        let id = UUID()
        let delegate = SharingLifecycleDelegate(
            id: id,
            onEnd: { [weak self] in
                onEnd?()
                self?.unregisterDelegate(id: id)
            },
            onBegin: { [weak self] in
                self?.beginInteraction()
            },
            onFinish: { [weak self] in
                self?.endInteraction()
            })
        activeDelegates[id] = delegate
        return delegate
    }

    private func unregisterDelegate(id: UUID) {
        activeDelegates.removeValue(forKey: id)
    }
}

public final class SharingLifecycleDelegate: NSObject, NSSharingServiceDelegate, NSSharingServicePickerDelegate {
    public let id: UUID
    private let onEnd: () -> Void
    private let onBegin: () -> Void
    private let onFinish: () -> Void

    private var pickerActive = false
    private var serviceInProgress = false
    private var finished = false
    private var timeoutTask: Task<Void, Never>?

    public init(id: UUID, onEnd: @escaping () -> Void, onBegin: @escaping () -> Void, onFinish: @escaping () -> Void) {
        self.id = id
        self.onEnd = onEnd
        self.onBegin = onBegin
        self.onFinish = onFinish
    }

    deinit {
        timeoutTask?.cancel()
    }

    public func markPickerBegan() {
        guard !pickerActive else { return }
        pickerActive = true
        onBegin()
    }

    public func markServiceBegan() {
        guard !serviceInProgress else { return }
        serviceInProgress = true
        onBegin()
        startTimeoutFallback()
    }

    private func startTimeoutFallback() {
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self = self, !Task.isCancelled else { return }
            if !self.finished {
                self.finishIfNeeded()
            }
        }
    }

    private func finishIfNeeded() {
        guard !finished else { return }
        finished = true
        timeoutTask?.cancel()
        onFinish()
        onEnd()
    }

    // MARK: - NSSharingServicePickerDelegate

    public func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        if service == nil {
            if pickerActive && !serviceInProgress {
                finishIfNeeded()
            }
            return
        }

        service?.delegate = self
        serviceInProgress = true
        startTimeoutFallback()
    }

    // MARK: - NSSharingServiceDelegate

    public func sharingService(_ sharingService: NSSharingService, willShareItems items: [Any]) {
        if !pickerActive && !serviceInProgress {
            onBegin()
        }
        serviceInProgress = true
    }

    public func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        finishIfNeeded()
    }

    public func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        finishIfNeeded()
    }
}
