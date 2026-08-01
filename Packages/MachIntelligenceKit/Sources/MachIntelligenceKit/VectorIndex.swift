import Foundation

public struct VectorRecord: Sendable, Equatable, Codable {
    public let id: String
    public let vector: [Float]
    public let metadata: [String: String]

    public init(id: String, vector: [Float], metadata: [String: String] = [:]) {
        self.id = id
        self.vector = vector
        self.metadata = metadata
    }
}

public struct VectorMatch: Sendable, Equatable {
    public let id: String
    public let score: Float
    public let metadata: [String: String]

    public init(id: String, score: Float, metadata: [String: String] = [:]) {
        self.id = id
        self.score = score
        self.metadata = metadata
    }
}

public enum VectorIndexError: Error, LocalizedError, Sendable {
    case invalidDimension(expected: Int, actual: Int)
    case noData
    case malformedData(String)
    case sqliteError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDimension(let expected, let actual):
            "Invalid vector dimension: expected \(expected), got \(actual)."
        case .noData:
            "No vector index data available."
        case .malformedData(let reason):
            "Malformed vector data: \(reason)."
        case .sqliteError(let reason):
            "SQLite vector index error: \(reason)."
        }
    }
}

public protocol VectorIndex: Sendable {
    var dimension: Int { get }

    func upsert(_ record: VectorRecord) throws
    func remove(_ id: String) throws
    func entries() throws -> [VectorRecord]
    func query(_ queryVector: [Float], topK: Int) throws -> [VectorMatch]
    func clear() throws
}

public func cosineSimilarity(_ lhs: [Float], _ rhs: [Float]) throws -> Float {
    guard lhs.count == rhs.count else {
        throw VectorIndexError.invalidDimension(expected: lhs.count, actual: rhs.count)
    }

    var dot: Float = 0
    var lhsMagnitude: Float = 0
    var rhsMagnitude: Float = 0

    for i in 0..<lhs.count {
        dot += lhs[i] * rhs[i]
        lhsMagnitude += lhs[i] * lhs[i]
        rhsMagnitude += rhs[i] * rhs[i]
    }

    let lhsNorm = sqrt(lhsMagnitude)
    let rhsNorm = sqrt(rhsMagnitude)

    guard lhsNorm > 0, rhsNorm > 0 else { return 0 }

    return dot / (lhsNorm * rhsNorm)
}
