//
//  DragDropServiceProtocol.swift
//  machNotch
//
//  Created as part of Phase 3 architectural refactoring.
//

import CoreGraphics
import Foundation

@MainActor
protocol DragDropServiceProtocol: AnyObject {
    var onDragEntersNotchRegion: (() -> Void)? { get set }
    var onDragExitsNotchRegion: (() -> Void)? { get set }
    var onDragMove: ((CGPoint) -> Void)? { get set }

    func startMonitoring()
    func stopMonitoring()
    func updateNotchRegion(_ region: CGRect)
}
