//
//  KeyboardBacklightServiceProtocol.swift
//  machNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation

@MainActor
public protocol KeyboardBacklightServiceProtocol: Observable {
    var rawBrightness: Float { get }
    func setRelative(delta: Float)
    func setAbsolute(value: Float)
    func refresh()
}
