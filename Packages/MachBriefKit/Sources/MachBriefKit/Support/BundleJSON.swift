import Foundation

enum BundleJSON {
    static func load<T: Decodable>(_ name: String, fallback: T) -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(T.self, from: data)
        else {
            return fallback
        }
        return decoded
    }
}
