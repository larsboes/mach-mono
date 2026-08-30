import Foundation

/// Persists one HealthKit query anchor per metric type.
///
/// `HKAnchoredObjectQuery` hands back an anchor marking how far a query has
/// read. Losing it costs correctness in both directions: without a stored
/// anchor the next launch either re-reads the entire history or, if the app
/// instead starts from "now", silently skips everything recorded while it was
/// closed. The anchor is opaque to us — HealthKit owns its meaning — so it is
/// stored as the bytes HealthKit produced.
public final class HealthAnchorStore: @unchecked Sendable {
  private let fileURL: URL
  private let lock = NSLock()
  private var anchors: [String: Data]

  public init(fileURL: URL) throws {
    self.fileURL = fileURL

    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    if let data = try? Data(contentsOf: fileURL),
      let restored = try? JSONDecoder().decode([String: Data].self, from: data)
    {
      anchors = restored
    } else {
      anchors = [:]
    }
  }

  public func anchor(for type: HealthMetricType) -> Data? {
    lock.lock()
    defer { lock.unlock() }
    return anchors[type.rawValue]
  }

  /// Passing nil forgets the anchor, which makes the next query re-read from
  /// the beginning. That is the deliberate way to force a backfill.
  public func setAnchor(_ data: Data?, for type: HealthMetricType) throws {
    lock.lock()
    if let data {
      anchors[type.rawValue] = data
    } else {
      anchors.removeValue(forKey: type.rawValue)
    }
    let snapshot = anchors
    lock.unlock()
    try persist(snapshot)
  }

  /// Metric types that have never been read, so a first run knows what to
  /// backfill rather than assuming the whole set is new.
  public func typesWithoutAnchor() -> [HealthMetricType] {
    lock.lock()
    defer { lock.unlock() }
    return HealthMetricType.allCases.filter { anchors[$0.rawValue] == nil }
  }

  public func reset() throws {
    lock.lock()
    anchors.removeAll()
    lock.unlock()
    try persist([:])
  }

  private func persist(_ snapshot: [String: Data]) throws {
    let data = try JSONEncoder().encode(snapshot)
    try data.write(to: fileURL, options: .atomic)
  }
}
