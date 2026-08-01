//
//  PermissionStateStore.swift
//  machNotch
//

import Foundation

public actor PermissionStateStore {
    private let defaults = UserDefaults.standard

    public init() {}

    private func key(for permission: PermissionType) -> String {
        return "hasRequested_\(permission.rawValue)"
    }

    public func hasRequested(_ permission: PermissionType) -> Bool {
        return defaults.bool(forKey: key(for: permission))
    }

    public func markRequested(_ permission: PermissionType) {
        defaults.set(true, forKey: key(for: permission))
        defaults.synchronize()
    }
}
