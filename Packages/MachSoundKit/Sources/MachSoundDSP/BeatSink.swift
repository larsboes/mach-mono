import Foundation
import os

/// A single visual beat record produced when a note actually sounds.
public struct BeatRecord: Sendable {
    public var kind: NoteBeatKind
    public var midi: Int32
    public init(kind: NoteBeatKind = .none, midi: Int32 = -1) {
        self.kind = kind
        self.midi = midi
    }
}

/// SPSC ring the render thread writes to when a beat-carrying note fires, drained
/// off the audio thread (e.g. on the scheduler tick) and forwarded to the
/// `beatEvents` AsyncStream.
///
/// This keeps `AsyncStream.Continuation.yield` — which may allocate/lock — off
/// the real-time render thread while still emitting beats at the exact frame a
/// note sounds (tight audio↔visual sync). Same `os_unfair_lock` rationale as
/// `EventQueue`.
public final class BeatSink {
    private var storage: [BeatRecord]
    private let capacity: Int
    private var head = 0
    private var tail = 0
    private let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)

    public init(capacity: Int = 512) {
        self.capacity = max(2, capacity)
        storage = [BeatRecord](repeating: BeatRecord(), count: self.capacity)
        lock.initialize(to: os_unfair_lock())
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    /// Producer (render thread). Drops silently if full.
    public func push(_ record: BeatRecord) {
        os_unfair_lock_lock(lock)
        let next = (tail + 1) % capacity
        if next != head {
            storage[tail] = record
            tail = next
        }
        os_unfair_lock_unlock(lock)
    }

    /// Consumer. Returns nil when empty.
    public func pop() -> BeatRecord? {
        os_unfair_lock_lock(lock)
        if head == tail {
            os_unfair_lock_unlock(lock)
            return nil
        }
        let r = storage[head]
        head = (head + 1) % capacity
        os_unfair_lock_unlock(lock)
        return r
    }
}
