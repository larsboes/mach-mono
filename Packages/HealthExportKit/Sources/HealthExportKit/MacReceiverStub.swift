import Foundation

/// In-memory Mac receiver reference implementation for H0 schema validation.
/// A Network.framework listener will replace this in a follow-up; machSound can
/// embed the delegate to derive arousal/sleep features on the Mac side.
public final class MacReceiverStub: @unchecked Sendable {
  public typealias Handler = (HealthExportPayload) -> Void

  private let lock = NSLock()
  private var handler: Handler?
  private(set) public var received: [HealthExportPayload] = []
  private(set) public var pairingToken: String?

  public init() {}

  public func setHandler(_ handler: Handler?) {
    lock.lock()
    self.handler = handler
    lock.unlock()
  }

  /// First-connect pairing: exchange a 6-digit code for a persistent token.
  @discardableResult
  public func pair(code: String) -> String? {
    guard code.count == 6, code.allSatisfy(\.isNumber) else { return nil }
    let token = UUID().uuidString
    lock.lock()
    pairingToken = token
    lock.unlock()
    return token
  }

  public func ingest(data: Data, token: String?) throws {
    guard let expected = pairingToken, token == expected else {
      throw MacReceiverError.unauthorized
    }
    let payload = try HealthExportSerializer.decode(data)
    lock.lock()
    received.append(payload)
    let handler = handler
    lock.unlock()
    handler?(payload)
  }

  public func reset() {
    lock.lock()
    received.removeAll()
    pairingToken = nil
    handler = nil
    lock.unlock()
  }
}

public enum MacReceiverError: Error, Equatable {
  case unauthorized
}
