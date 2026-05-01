//
//  Sequence+Async.swift
//  boringNotch
//
//  Async collection helpers extracted from ShelfMenuActionTarget.
//

import Foundation

extension Sequence {
    func asyncCompactMap<T>(_ transform: (Element) async -> T?) async -> [T] {
        var result: [T] = []
        for element in self {
            if let transformed = await transform(element) {
                result.append(transformed)
            }
        }
        return result
    }
}
