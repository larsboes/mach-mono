//
//  ShelfFileHandlerProtocol.swift
//  boringNotch
//
//  Created by Refactoring Agent on 2026-01-01.
//

import AppKit
import Foundation

@MainActor
protocol ShelfFileHandlerProtocol: Sendable {
    var temporaryFileStorage: any TemporaryFileStorageServiceProtocol { get }
    
    func rename(item: ShelfItem, newName: String, service: ShelfServiceProtocol, completion: @escaping (Bool) -> Void)
    func showInFinder(items: [ShelfItem], service: ShelfServiceProtocol)
    func copyPath(items: [ShelfItem])
    func compress(items: [ShelfItem], service: ShelfServiceProtocol)
    func open(items: [ShelfItem], with appURL: URL?)
}
