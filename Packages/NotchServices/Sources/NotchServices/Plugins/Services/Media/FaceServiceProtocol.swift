//
//  FaceServiceProtocol.swift
//  machNotch
//
//  Created as part of Phase 3 architectural refactoring.
//

import CoreGraphics
import Foundation

@MainActor
public protocol FaceServiceProtocol: AnyObject {
    var eyeOffset: CGSize { get }
    var isSleepy: Bool { get }

    func startMonitoring()
    func stopMonitoring()
}
