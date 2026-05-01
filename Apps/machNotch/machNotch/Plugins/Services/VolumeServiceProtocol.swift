//
//  VolumeServiceProtocol.swift
//  boringNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation

@MainActor
protocol VolumeServiceProtocol: Observable {
    var rawVolume: Float { get }
    var isMuted: Bool { get }
    func increase(stepDivisor: Float)
    func decrease(stepDivisor: Float)
    func toggleMuteAction()
    func setAbsolute(_ value: Float)
    func refresh()
}
