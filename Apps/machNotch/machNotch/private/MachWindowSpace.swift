//
//  MachWindowSpace.swift
//  machNotch
//
//  Created by machNotch
//  MIT License
//

import AppKit

/// Small Spaces API wrapper.
@MainActor
public final class MachWindowSpace {
    private let identifier: CGSSpaceID

    public var windowNumbers: [CGWindowID] = [] {
        didSet {
            let oldSet = Set(oldValue)
            let newSet = Set(self.windowNumbers)

            let remove = oldSet.subtracting(newSet)
            let add = newSet.subtracting(oldSet)

            CGSRemoveWindowsFromSpaces(
                _CGSDefaultConnection(),
                Array(remove) as NSArray,
                [self.identifier] as NSArray)
            CGSAddWindowsToSpaces(
                _CGSDefaultConnection(),
                Array(add) as NSArray,
                [self.identifier] as NSArray)
        }
    }

    public func register(_ window: NSWindow) {
        let windowID = CGWindowID(window.windowNumber)
        guard !windowNumbers.contains(windowID) else { return }
        windowNumbers.append(windowID)
    }

    public func unregister(_ window: NSWindow) {
        let windowID = CGWindowID(window.windowNumber)
        windowNumbers.removeAll { $0 == windowID }
    }

    /// Initialized `MachWindowSpace`s *MUST* be de-initialized upon app exit!
    public init(level: Int = 0) {
        let flag = 0x1  // this value MUST be 1, otherwise, Finder decides to draw desktop icons
        self.identifier = CGSSpaceCreate(_CGSDefaultConnection(), flag, nil)
        CGSSpaceSetAbsoluteLevel(_CGSDefaultConnection(), self.identifier, level)
        CGSShowSpaces(_CGSDefaultConnection(), [self.identifier] as NSArray)
    }

    deinit {
        CGSHideSpaces(_CGSDefaultConnection(), [self.identifier] as NSArray)
        CGSSpaceDestroy(_CGSDefaultConnection(), self.identifier)
    }
}

// CGSSpace stuff:
private typealias CGSConnectionID = UInt
private typealias CGSSpaceID = UInt64
@_silgen_name("_CGSDefaultConnection")
private func _CGSDefaultConnection() -> CGSConnectionID
@_silgen_name("CGSSpaceCreate")
private func CGSSpaceCreate(_ cid: CGSConnectionID, _ unknown: Int, _ options: NSDictionary?) -> CGSSpaceID
@_silgen_name("CGSSpaceDestroy")
private func CGSSpaceDestroy(_ cid: CGSConnectionID, _ space: CGSSpaceID)
@_silgen_name("CGSSpaceSetAbsoluteLevel")
private func CGSSpaceSetAbsoluteLevel(_ cid: CGSConnectionID, _ space: CGSSpaceID, _ level: Int)
@_silgen_name("CGSAddWindowsToSpaces")
private func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)
@_silgen_name("CGSRemoveWindowsFromSpaces")
private func CGSRemoveWindowsFromSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)
@_silgen_name("CGSHideSpaces")
private func CGSHideSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)
@_silgen_name("CGSShowSpaces")
private func CGSShowSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)
