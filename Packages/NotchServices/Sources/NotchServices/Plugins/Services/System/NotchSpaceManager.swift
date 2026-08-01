//
//  NotchSpaceManager.swift
//  machNotch
//
//  Created by Alexander on 2024-10-27.
//

import Foundation

@MainActor
public final class NotchSpaceManager {
    public let notchSpace: MachWindowSpace
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public init() {
        notchSpace = MachWindowSpace(level: 2147483647)  // Max level
    }
}
