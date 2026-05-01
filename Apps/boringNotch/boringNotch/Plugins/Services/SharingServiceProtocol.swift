//
//  SharingServiceProtocol.swift
//  boringNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation

@MainActor
protocol SharingServiceProtocol: Observable {
    var preventNotchClose: Bool { get }
    func requestCloseIfReady()
    func beginInteraction()
    func endInteraction()
    func makeDelegate(onEnd: (() -> Void)?) -> SharingLifecycleDelegate
}
