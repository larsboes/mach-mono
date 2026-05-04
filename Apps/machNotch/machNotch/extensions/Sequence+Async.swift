//
//  Sequence+Async.swift
//  machNotch
//
//  Async collection helpers extracted from ShelfMenuActionTarget.
//

import Foundation

extension Sequence {
    func asyncCompactMap<T>(_ transform: @Sendable (Element) async -> T?) async -> [T] {
        var result: [T] = []
        for element in self {
            if let transformed = await transform(element) {
                result.append(transformed)
            }
        }
        return result
    }
}
