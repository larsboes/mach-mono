//
//  NotchObserverManager.swift
//  boringNotch
//
//  Extracted from BoringViewModel - handles observer setup and background image management
//

import Combine
// NOTE: Defaults.updates/publisher needed for reactive observation — see NavigationState.swift comment.
import Defaults
import SwiftUI

/// Manager for setting up observers and background image handling
@MainActor
class NotchObserverManager {
    // MARK: - Dependencies

    /// Settings provider (injected, not direct Defaults access)
    private let settings: NotchViewModelSettings

    /// Fullscreen media detector for hide-on-closed functionality
    private let detector: FullscreenMediaDetector

    // MARK: - State

    var backgroundImage: NSImage?
    private var cancellables: Set<AnyCancellable> = []
    private var observerTasks: [Task<Void, Never>] = []

    // MARK: - Initialization

    init(
        settings: NotchViewModelSettings,
        detector: FullscreenMediaDetector
    ) {
        self.settings = settings
        self.detector = detector
    }

    deinit {
        observerTasks.forEach { $0.cancel() }
    }

    // MARK: - Observer Setup

    /// Setup detector observer for hide-on-closed functionality
    func setupDetectorObserver(
        screenUUID: String?,
        onHideOnClosedChanged: @escaping (Bool) -> Void
    ) {
        let defaultsTask = Task { @MainActor in
            // Observe Defaults changes
            for await _ in Defaults.updates(.hideNotchOption) {
                if Task.isCancelled { break }
                let shouldHide = calculateHideOnClosed(screenUUID: screenUUID)
                onHideOnClosedChanged(shouldHide)
            }
        }
        observerTasks.append(defaultsTask)

        let trackingTask = Task { @MainActor in
            // React to @Observable changes via withObservationTracking
            while !Task.isCancelled {
                let shouldHide = withObservationTracking {
                    calculateHideOnClosed(screenUUID: screenUUID)
                } onChange: { }

                onHideOnClosedChanged(shouldHide)

                // Yield until the observed properties change
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.detector.fullscreenStatus
                    } onChange: {
                        continuation.resume()
                    }
                }
            }
        }
        observerTasks.append(trackingTask)
    }

    /// Calculate whether notch should be hidden when closed
    private func calculateHideOnClosed(screenUUID: String?) -> Bool {
        let enabled = settings.hideNotchOption != .never
        let status = detector.fullscreenStatus

        if let uuid = screenUUID {
            return enabled && (status[uuid] ?? false)
        }
        return false
    }

    /// Setup background image observer
    func setupBackgroundImageObserver(
        onImageChanged: @escaping (NSImage?) -> Void
    ) {
        Defaults.publisher(.backgroundImageURL)
            .map(\.newValue)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                self?.loadBackgroundImage(from: url, onImageChanged: onImageChanged)
            }
            .store(in: &cancellables)

        if let url = settings.backgroundImageURL {
            loadBackgroundImage(from: url, onImageChanged: onImageChanged)
        }
    }

    /// Load background image from URL
    private func loadBackgroundImage(
        from url: URL?,
        onImageChanged: @escaping (NSImage?) -> Void
    ) {
        guard let url = url else {
            backgroundImage = nil
            onImageChanged(nil)
            return
        }

        let image = NSImage(contentsOf: url)
        backgroundImage = image
        onImageChanged(image)
    }

    /// Copy background image to app storage
    static func copyBackgroundImageToAppStorage(sourceURL: URL) -> URL? {
        let fm = FileManager.default

        guard let supportDir = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        let targetDir = supportDir
            .appendingPathComponent("boringNotch", isDirectory: true)
            .appendingPathComponent("Background", isDirectory: true)

        do {
            try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let fileExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let destinationURL = targetDir.appendingPathComponent("background.\(fileExtension)")

        if fm.fileExists(atPath: destinationURL.path) {
            try? fm.removeItem(at: destinationURL)
        }

        do {
            let didStartAccessing = sourceURL.isFileURL ? sourceURL.startAccessingSecurityScopedResource() : false
            defer {
                if didStartAccessing {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            try fm.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            return nil
        }
    }
}
