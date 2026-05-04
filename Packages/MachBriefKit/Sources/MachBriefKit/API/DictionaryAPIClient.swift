import Foundation

public struct DictionaryWordDetail: Sendable {
    public let word: String
    public let definition: String?
    public let partOfSpeech: String?
    public let example: String?
}

public protocol DictionaryAPIClientProtocol: Sendable {
    func lookup(word: String) async -> DictionaryWordDetail?
}

public struct DictionaryAPIClient: DictionaryAPIClientProtocol {
    public init() {}

    public func lookup(word: String) async -> DictionaryWordDetail? {
        guard let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(word)") else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([DictionaryResponse].self, from: data)
            guard let first = decoded.first else { return nil }
            let meaning = first.meanings.first
            return DictionaryWordDetail(
                word: first.word,
                definition: meaning?.definitions.first?.definition,
                partOfSpeech: meaning?.partOfSpeech,
                example: meaning?.definitions.first?.example
            )
        } catch {
            return nil
        }
    }
}

private struct DictionaryResponse: Codable {
    let word: String
    let meanings: [Meaning]
}

private struct Meaning: Codable {
    let partOfSpeech: String?
    let definitions: [Definition]
}

private struct Definition: Codable {
    let definition: String?
    let example: String?
}
