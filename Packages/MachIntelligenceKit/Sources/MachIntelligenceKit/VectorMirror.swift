import Accelerate
import Foundation

/// In-memory mirror of an index's vectors, holding the query path.
///
/// Reading and JSON-decoding every row per query costs about 1.2 s at 10k
/// items, which is 25x the 50 ms budget, so queries are answered from here and
/// never touch storage. Vectors are kept L2-normalized in one flat buffer, so a
/// cosine similarity is a single `vDSP_dotpr` over a contiguous slice with no
/// per-query magnitude work.
struct VectorMirror {
    private(set) var ids: [String] = []
    private var unitVectors: [Float] = []
    private var metadatas: [[String: String]] = []
    private var positionByID: [String: Int] = [:]

    /// Row width. Rebuilding the buffer at a new width is the caller's job.
    var dimension: Int

    init(dimension: Int = 0) {
        self.dimension = dimension
    }

    var isEmpty: Bool { ids.isEmpty }

    mutating func removeAll() {
        unitVectors.removeAll(keepingCapacity: true)
        ids.removeAll(keepingCapacity: true)
        metadatas.removeAll(keepingCapacity: true)
        positionByID.removeAll(keepingCapacity: true)
    }

    mutating func load(_ records: [VectorRecord]) {
        removeAll()
        unitVectors.reserveCapacity(records.count * max(dimension, 1))
        for record in records where record.vector.count == dimension {
            store(id: record.id, vector: record.vector, metadata: record.metadata)
        }
    }

    mutating func store(id: String, vector: [Float], metadata: [String: String]) {
        guard let unit = Self.normalized(vector), unit.count == dimension else { return }

        if let position = positionByID[id] {
            let start = position * dimension
            unitVectors.replaceSubrange(start..<(start + dimension), with: unit)
            metadatas[position] = metadata
        } else {
            positionByID[id] = ids.count
            ids.append(id)
            metadatas.append(metadata)
            unitVectors.append(contentsOf: unit)
        }
    }

    mutating func discard(id: String) {
        guard let position = positionByID.removeValue(forKey: id), dimension > 0 else { return }

        let last = ids.count - 1
        if position != last {
            // Move the last row into the hole so the buffer stays contiguous.
            let lastStart = last * dimension
            let lastRow = Array(unitVectors[lastStart..<(lastStart + dimension)])
            let holeStart = position * dimension
            unitVectors.replaceSubrange(holeStart..<(holeStart + dimension), with: lastRow)
            ids[position] = ids[last]
            metadatas[position] = metadatas[last]
            positionByID[ids[position]] = position
        }

        unitVectors.removeLast(dimension)
        ids.removeLast()
        metadatas.removeLast()
    }

    func topMatches(for queryVector: [Float], limit: Int) -> [VectorMatch] {
        guard limit > 0, !ids.isEmpty, dimension > 0,
            let probe = Self.normalized(queryVector), probe.count == dimension
        else { return [] }

        var scores = [Float](repeating: 0, count: ids.count)
        let width = dimension

        unitVectors.withUnsafeBufferPointer { stored in
            probe.withUnsafeBufferPointer { needle in
                guard let base = stored.baseAddress, let target = needle.baseAddress else { return }
                for row in 0..<ids.count {
                    vDSP_dotpr(base + row * width, 1, target, 1, &scores[row], vDSP_Length(width))
                }
            }
        }

        return scores.indices
            .sorted { scores[$0] > scores[$1] }
            .prefix(limit)
            .map { VectorMatch(id: ids[$0], score: scores[$0], metadata: metadatas[$0]) }
    }

    static func normalized(_ vector: [Float]) -> [Float]? {
        guard !vector.isEmpty else { return nil }

        var magnitude: Float = 0
        vDSP_svesq(vector, 1, &magnitude, vDSP_Length(vector.count))
        let norm = sqrt(magnitude)
        guard norm > 0, norm.isFinite else { return nil }

        var scale = 1 / norm
        var unit = [Float](repeating: 0, count: vector.count)
        vDSP_vsmul(vector, 1, &scale, &unit, 1, vDSP_Length(vector.count))
        return unit
    }
}
