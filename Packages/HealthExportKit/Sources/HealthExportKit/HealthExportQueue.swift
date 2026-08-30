import Foundation

/// A queued payload and its delivery history.
public struct QueuedExport: Codable, Sendable, Equatable, Identifiable {
  public let id: String
  public let payload: HealthExportPayload
  public internal(set) var attempts: Int
  public internal(set) var lastAttemptAt: Date?

  public init(
    id: String = UUID().uuidString,
    payload: HealthExportPayload,
    attempts: Int = 0,
    lastAttemptAt: Date? = nil
  ) {
    self.id = id
    self.payload = payload
    self.attempts = attempts
    self.lastAttemptAt = lastAttemptAt
  }
}

public struct FlushSummary: Sendable, Equatable {
  public let delivered: Int
  public let failed: Int
  public let skipped: Int
  public let exhausted: Int

  public init(delivered: Int, failed: Int, skipped: Int, exhausted: Int) {
    self.delivered = delivered
    self.failed = failed
    self.skipped = skipped
    self.exhausted = exhausted
  }
}

/// Durable outbound queue for health exports, with at-least-once delivery.
///
/// A phone that walks out of LAN range mid-export must not lose the samples, so
/// an entry is removed only after the send returns without throwing. The cost of
/// that guarantee is that a send which succeeds on the wire but fails afterwards
/// is retried, and the Mac receives it twice — which is why `HealthSample`
/// carries the HealthKit `uuid`. The receiver deduplicates on it.
///
/// State is written to disk on every mutation, so a crash between the send and
/// the acknowledgement resumes rather than drops.
public final class HealthExportQueue: @unchecked Sendable {
  private let fileURL: URL
  private let maxAttempts: Int
  private let lock = NSLock()
  private var entries: [QueuedExport]

  private static let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    e.outputFormatting = [.sortedKeys]
    return e
  }()

  private static let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }()

  /// - Parameter maxAttempts: after this many failures an entry stops being
  ///   retried automatically. It is kept, not deleted — losing health data
  ///   silently is worse than a queue that needs draining.
  public init(fileURL: URL, maxAttempts: Int = 5) throws {
    self.fileURL = fileURL
    self.maxAttempts = max(1, maxAttempts)

    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    if let data = try? Data(contentsOf: fileURL),
      let restored = try? Self.decoder.decode([QueuedExport].self, from: data)
    {
      entries = restored
    } else {
      entries = []
    }
  }

  // MARK: - Inspection

  public var pendingCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return entries.filter { $0.attempts < maxAttempts }.count
  }

  public var exhaustedCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return entries.filter { $0.attempts >= maxAttempts }.count
  }

  public var allEntries: [QueuedExport] {
    lock.lock()
    defer { lock.unlock() }
    return entries
  }

  // MARK: - Mutation

  public func enqueue(_ payload: HealthExportPayload) throws {
    lock.lock()
    entries.append(QueuedExport(payload: payload))
    let snapshot = entries
    lock.unlock()
    try persist(snapshot)
  }

  /// Backoff before the next attempt: 2s, 4s, 8s, ... capped at five minutes.
  public func retryDelay(forAttempt attempt: Int) -> TimeInterval {
    guard attempt > 0 else { return 0 }
    return min(pow(2, Double(min(attempt, 10))), 300)
  }

  /// Attempts delivery of every entry that is due.
  ///
  /// `send` throwing means the payload was not delivered and stays queued.
  public func flush(
    now: Date = .now,
    send: (HealthExportPayload) async throws -> Void
  ) async -> FlushSummary {
    lock.lock()
    let snapshot = entries
    lock.unlock()

    var delivered = 0
    var failed = 0
    var skipped = 0
    var deliveredIDs: Set<String> = []
    var updatedAttempts: [String: (Int, Date)] = [:]

    for entry in snapshot {
      if entry.attempts >= maxAttempts {
        continue
      }
      if let last = entry.lastAttemptAt,
        now.timeIntervalSince(last) < retryDelay(forAttempt: entry.attempts)
      {
        skipped += 1
        continue
      }

      do {
        try await send(entry.payload)
        deliveredIDs.insert(entry.id)
        delivered += 1
      } catch {
        updatedAttempts[entry.id] = (entry.attempts + 1, now)
        failed += 1
      }
    }

    lock.lock()
    entries.removeAll { deliveredIDs.contains($0.id) }
    for index in entries.indices {
      if let (attempts, at) = updatedAttempts[entries[index].id] {
        entries[index].attempts = attempts
        entries[index].lastAttemptAt = at
      }
    }
    let updated = entries
    let exhausted = entries.filter { $0.attempts >= maxAttempts }.count
    lock.unlock()

    try? persist(updated)

    return FlushSummary(
      delivered: delivered, failed: failed, skipped: skipped, exhausted: exhausted)
  }

  /// Clears entries that exhausted their attempts, after the caller has dealt
  /// with them. Nothing else removes them.
  public func drainExhausted() throws -> [QueuedExport] {
    lock.lock()
    let dropped = entries.filter { $0.attempts >= maxAttempts }
    entries.removeAll { $0.attempts >= maxAttempts }
    let snapshot = entries
    lock.unlock()
    try persist(snapshot)
    return dropped
  }

  public func removeAll() throws {
    lock.lock()
    entries.removeAll()
    lock.unlock()
    try persist([])
  }

  private func persist(_ snapshot: [QueuedExport]) throws {
    let data = try Self.encoder.encode(snapshot)
    try data.write(to: fileURL, options: .atomic)
  }
}
