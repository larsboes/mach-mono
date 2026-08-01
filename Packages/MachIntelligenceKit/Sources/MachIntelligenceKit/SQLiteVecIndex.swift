import Foundation
import SQLite

public final class SQLiteVecIndex: VectorIndex, @unchecked Sendable {
    private let connection: Connection
    private let table: Table
    private let idColumn = Expression<String>("id")
    private let vectorColumn = Expression<String>("vector")
    private let metadataColumn = Expression<String>("metadata")
    private let dimensionColumn = Expression<Int>("dimension")
    private let updatedAtColumn = Expression<Double>("updated_at")
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public private(set) var dimension: Int

    public init(databaseURL: URL, tableName: String = "vectors") throws {
        self.dimension = 0
        self.table = Table(tableName)

        do {
            try FileManager.default.createDirectory(
                at: databaseURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            connection = try Connection(databaseURL.path)
            try connection.run(table.create(ifNotExists: true) { t in
                t.column(idColumn, primaryKey: true)
                t.column(dimensionColumn)
                t.column(vectorColumn)
                t.column(metadataColumn)
                t.column(updatedAtColumn)
            })
            if let first = try connection.pluck(table) {
                dimension = first[dimensionColumn]
            }
        } catch {
            throw VectorIndexError.sqliteError(error.localizedDescription)
        }
    }

    public func upsert(_ record: VectorRecord) throws {
        if record.vector.isEmpty {
            throw VectorIndexError.invalidDimension(expected: max(1, dimension), actual: 0)
        }

        if dimension == 0 {
            dimension = record.vector.count
        } else if record.vector.count != dimension {
            throw VectorIndexError.invalidDimension(expected: dimension, actual: record.vector.count)
        }

        do {
            let encodedVector = try encoder.encode(record.vector)
            let encodedMetadata = try encoder.encode(record.metadata)

            guard
                let vectorString = String(data: encodedVector, encoding: .utf8),
                let metadataString = String(data: encodedMetadata, encoding: .utf8)
            else {
                throw VectorIndexError.malformedData("Vector payload is not valid UTF-8.")
            }

            let entry = table.filter(idColumn == record.id)
            if try connection.scalar(entry.count) == 0 {
                try connection.run(entry.insert(
                    idColumn <- record.id,
                    vectorColumn <- vectorString,
                    metadataColumn <- metadataString,
                    dimensionColumn <- record.vector.count,
                    updatedAtColumn <- Date().timeIntervalSince1970
                ))
            } else {
                try connection.run(entry.update(
                    vectorColumn <- vectorString,
                    metadataColumn <- metadataString,
                    dimensionColumn <- record.vector.count,
                    updatedAtColumn <- Date().timeIntervalSince1970
                ))
            }
        } catch {
            throw VectorIndexError.sqliteError(error.localizedDescription)
        }
    }

    public func remove(_ id: String) throws {
        do {
            let entry = table.filter(idColumn == id)
            try connection.run(entry.delete())

            if try connection.scalar(table.count) == 0 {
                dimension = 0
            }
        } catch {
            throw VectorIndexError.sqliteError(error.localizedDescription)
        }
    }

    public func clear() throws {
        do {
            try connection.run(table.delete())
            dimension = 0
        } catch {
            throw VectorIndexError.sqliteError(error.localizedDescription)
        }
    }

    public func entries() throws -> [VectorRecord] {
        do {
            return try connection.prepare(table)
                .compactMap { row in
                    do {
                        let vector = try decodeVector(row[vectorColumn])
                        let metadata = try decodeMetadata(row[metadataColumn])
                        return VectorRecord(
                            id: row[idColumn],
                            vector: vector,
                            metadata: metadata
                        )
                    } catch {
                        return nil
                    }
                }
        } catch {
            throw VectorIndexError.sqliteError(error.localizedDescription)
        }
    }

    public func query(_ queryVector: [Float], topK: Int) throws -> [VectorMatch] {
        if topK <= 0 || dimension == 0 {
            return []
        }

        if queryVector.count != dimension {
            throw VectorIndexError.invalidDimension(expected: dimension, actual: queryVector.count)
        }

        let all = try entries()
        guard !all.isEmpty else { return [] }

        let ranked = try all
            .map { item -> VectorMatch in
                VectorMatch(id: item.id, score: try cosineSimilarity(item.vector, queryVector), metadata: item.metadata)
            }
            .sorted { $0.score > $1.score }

        return Array(ranked.prefix(topK))
    }

    private func decodeVector(_ raw: String) throws -> [Float] {
        guard let data = raw.data(using: .utf8) else {
            throw VectorIndexError.malformedData("Vector payload is not UTF-8.")
        }

        do {
            return try decoder.decode([Float].self, from: data)
        } catch {
            do {
                let values = try decoder.decode([Double].self, from: data)
                return values.map { Float($0) }
            } catch {
                throw VectorIndexError.malformedData("Vector payload is not valid JSON.")
            }
        }
    }

    private func decodeMetadata(_ raw: String) throws -> [String: String] {
        guard let data = raw.data(using: .utf8) else {
            throw VectorIndexError.malformedData("Metadata payload is not UTF-8.")
        }

        do {
            return try decoder.decode([String: String].self, from: data)
        } catch {
            throw VectorIndexError.malformedData("Metadata payload is not valid JSON.")
        }
    }
}
