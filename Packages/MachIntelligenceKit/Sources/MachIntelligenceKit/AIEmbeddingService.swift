public protocol AIEmbeddingService: Sendable {
    func embedding(for text: String) async throws -> [Float]
}
