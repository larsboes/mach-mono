//
//  NSMenu+AssociatedObject.swift
//  NotchServices
//

import AppKit

private final class MenuActionBox: NSObject {
    let target: AnyObject
    init(target: AnyObject) { self.target = target }
}

public extension NSMenu {
    // Each NSMenu instance can store one retained target
    nonisolated(unsafe) private static let retainedAction = AssociatedObject<MenuActionBox>()

    func retainActionTarget(_ target: AnyObject) {
        NSMenu.retainedAction[self] = MenuActionBox(target: target)
    }
}
