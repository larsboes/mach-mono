import Foundation

public struct DictionaryWordDetail: Sendable {
    public let word: String
    public let definition: String?
    public let partOfSpeech: String?
    public let phonetic: String?
    public let example: String?
}

public protocol DictionaryAPIClientProtocol: Sendable {
    func lookup(word: String, languageCode: String) async -> DictionaryWordDetail?
}

public struct DictionaryAPIClient: DictionaryAPIClientProtocol {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 4
        config.timeoutIntervalForResource = 4
        return URLSession(configuration: config)
    }()

    public init() {}

    public func lookup(word: String, languageCode: String = "en") async -> DictionaryWordDetail? {
        guard let encodedWord = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/\(languageCode)/\(encodedWord)")
        else {
            return nil
        }
        do {
            let (data, _) = try await Self.session.data(from: url)
            let decoded = try JSONDecoder().decode([DictionaryResponse].self, from: data)
            guard let first = decoded.first else { return nil }
            let meaning = first.meanings.first
            return DictionaryWordDetail(
                word: first.word,
                definition: meaning?.definitions.first?.definition,
                partOfSpeech: meaning?.partOfSpeech,
                phonetic: first.phonetic ?? first.phonetics.first(where: { $0.text != nil })?.text,
                example: meaning?.definitions.first?.example
            )
        } catch {
            return nil
        }
    }
}

private struct DictionaryResponse: Codable {
    let word: String
    let phonetic: String?
    let phonetics: [Phonetic]
    let meanings: [Meaning]
}

private struct Phonetic: Codable {
    let text: String?
}

private struct Meaning: Codable {
    let partOfSpeech: String?
    let definitions: [Definition]
}

private struct Definition: Codable {
    let definition: String?
    let example: String?
}
