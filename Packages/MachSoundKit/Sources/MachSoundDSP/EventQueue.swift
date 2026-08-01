import Foundation
import os

/// Single-producer / single-consumer ring buffer of `NoteEvent`s.
///
/// Producer: the scheduler thread (`enqueue`). Consumer: the audio render thread
/// (`dequeue`, drained once per render block). Guarded by `os_unfair_lock` with
/// a microscopic critical section (copy one POD struct + advance an index).
///
/// This is not strictly lock-free — `Synchronization.Atomic` needs macOS 15 and
/// the package targets macOS 14, and adding a C atomics shim to the Bazel
/// `swift_library` is heavier than warranted right now. A once-per-block
/// uncontended `os_unfair_lock` is the pragmatic real-time-safe choice and is
/// still a massive improvement over the old wall-clock `DispatchQueue.asyncAfter`
/// scheduling. Revisit (true lock-free) if profiling shows contention.
public final class EventQueue {
    private var storage: [NoteEvent]
    private let capacity: Int
    private var head = 0   // next slot to read
    private var tail = 0   // next slot to write
    private let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)

    public init(capacity: Int = 1024) {
        self.capacity = max(2, capacity)
        storage = [NoteEvent](repeating: NoteEvent(), count: self.capacity)
        lock.initialize(to: os_unfair_lock())
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    /// Producer side. Returns false if the queue is full (event dropped).
    @discardableResult
    public func enqueue(_ event: NoteEvent) -> Bool {
        os_unfair_lock_lock(lock)
        let next = (tail + 1) % capacity
        if next == head {
            os_unfair_lock_unlock(lock)
            return false
        }
        storage[tail] = event
        tail = next
        os_unfair_lock_unlock(lock)
        return true
    }

    /// Consumer side. Returns nil when empty.
    public func dequeue() -> NoteEvent? {
        os_unfair_lock_lock(lock)
        if head == tail {
            os_unfair_lock_unlock(lock)
            return nil
        }
        let event = storage[head]
        head = (head + 1) % capacity
        os_unfair_lock_unlock(lock)
        return event
    }

    /// Approximate count (for tests/diagnostics; not for render-thread logic).
    public var count: Int {
        os_unfair_lock_lock(lock)
        let c = (tail - head + capacity) % capacity
        os_unfair_lock_unlock(lock)
        return c
    }
}
