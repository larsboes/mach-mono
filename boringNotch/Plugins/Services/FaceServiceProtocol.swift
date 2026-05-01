//
//  FaceServiceProtocol.swift
//  boringNotch
//
//  Created as part of Phase 3 architectural refactoring.
//

import Foundation
import CoreGraphics

@MainActor
protocol FaceServiceProtocol: AnyObject {
    var eyeOffset: CGSize { get }
    var isSleepy: Bool { get }
    
    func startMonitoring()
    func stopMonitoring()
}
