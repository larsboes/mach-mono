//
//  PluginDescriptorRegistration.swift
//  NotchPlugins
//
//  Batch results for metadata-first plugin discovery.
//

import Foundation

public struct PluginDescriptorRegistrationResult: Sendable {
    public let registeredIDs: [String]
    public let skippedIDs: [String]

    public init(registeredIDs: [String], skippedIDs: [String]) {
        self.registeredIDs = registeredIDs
        self.skippedIDs = skippedIDs
    }
}
