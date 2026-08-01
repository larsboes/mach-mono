import Foundation

public enum HealthExportSerializer {
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

  public static func encode(_ payload: HealthExportPayload) throws -> Data {
    guard payload.schema == HealthExportSchema.current else {
      throw HealthExportError.unsupportedSchema(payload.schema)
    }
    return try encoder.encode(payload)
  }

  public static func decode(_ data: Data) throws -> HealthExportPayload {
    let payload = try decoder.decode(HealthExportPayload.self, from: data)
    guard payload.schema == HealthExportSchema.current else {
      throw HealthExportError.unsupportedSchema(payload.schema)
    }
    return payload
  }
}

public enum HealthExportError: Error, Equatable {
  case unsupportedSchema(Int)
}
