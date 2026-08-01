import CryptoKit
import Foundation

enum SHA1 {
    static func hash(data: Data) -> [UInt8] {
        let digest = Insecure.SHA1.hash(data: data)
        return Array(digest)
    }
}
