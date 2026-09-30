//
//  AppleScriptHelper.swift
//  machNotch
//
//  Created by Alexander on 2025-03-29.
//
//  Compiles each script once and reuses the compiled form. The playback-state
//  scripts run on every media poll, and for scripts this small `NSAppleScript`
//  spends most of its time compiling rather than executing.
//
//  `NSAppleScript` is not thread-safe, so the cache and every execution stay on
//  one serial queue. That also serializes the Apple Events themselves, which is
//  what we want — they all target the same handful of media apps.
//

import Foundation

class AppleScriptHelper {
    /// Bounded because a few call sites interpolate values into the source
    /// (`AppleMusicController.setFavorite`, `SpotifyController.executeCommand`).
    /// The real key space is small; the cap only stops unbounded growth.
    private static let cacheCapacity = 32

    private static let queue = DispatchQueue(label: "com.machnotch.applescript")
    private nonisolated(unsafe) static var cache: [String: NSAppleScript] = [:]
    private nonisolated(unsafe) static var insertionOrder: [String] = []

    /// Must be called on `queue`.
    private static func compiledScript(for source: String) -> NSAppleScript? {
        if let cached = cache[source] { return cached }

        guard let script = NSAppleScript(source: source) else { return nil }
        var compileError: NSDictionary?
        guard script.compileAndReturnError(&compileError) else { return nil }

        if insertionOrder.count >= cacheCapacity, let oldest = insertionOrder.first {
            cache.removeValue(forKey: oldest)
            insertionOrder.removeFirst()
        }
        cache[source] = script
        insertionOrder.append(source)
        return script
    }

    @discardableResult
    class func execute(_ scriptText: String) async throws -> NSAppleEventDescriptor? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard let script = compiledScript(for: scriptText) else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "AppleScriptError", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Could not compile script"]))
                    return
                }

                var error: NSDictionary?
                let descriptor = script.executeAndReturnError(&error)
                if let error = error {
                    continuation.resume(
                        throwing: NSError(domain: "AppleScriptError", code: 1, userInfo: error as? [String: Any]))
                } else {
                    continuation.resume(returning: descriptor)
                }
            }
        }
    }

    class func executeVoid(_ scriptText: String) async throws {
        _ = try await execute(scriptText)
    }
}
