//
//  BrightnessServiceProtocol.swift
//  boringNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation

@MainActor
protocol BrightnessServiceProtocol: Observable {
    var rawBrightness: Float { get }
    func setRelative(delta: Float)
    func setAbsolute(value: Float)
    func refresh()
}
