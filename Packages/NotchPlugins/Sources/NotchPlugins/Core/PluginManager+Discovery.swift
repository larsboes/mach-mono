//
//  PluginManager+Discovery.swift
//  NotchPlugins
//
//  Descriptor-only registration for discovered external plugins.
//

import Foundation

@MainActor
extension PluginManager {
    public var externalPluginSummaries: [PluginSummary] {
        allPluginSummaries.filter(\.isExternal)
    }

    @discardableResult
    public func registerDiscoveredDescriptors(
        _ discoveredDescriptors: [PluginDescriptor],
        replacingExisting: Bool = false,
        defaultEnabled: Bool = false
    ) -> PluginDescriptorRegistrationResult {
        var registeredIDs: [String] = []
        var skippedIDs: [String] = []

        for descriptor in discoveredDescriptors {
            if shouldSkipDiscoveredDescriptor(descriptor, replacingExisting: replacingExisting) {
                skippedIDs.append(descriptor.id)
                continue
            }

            descriptors[descriptor.id] = descriptor
            pluginEnabledState[descriptor.id] = pluginEnabledState[descriptor.id] ?? defaultEnabled
            if !pluginOrder.contains(descriptor.id) {
                pluginOrder.append(descriptor.id)
            }
            registeredIDs.append(descriptor.id)
        }

        return PluginDescriptorRegistrationResult(
            registeredIDs: registeredIDs,
            skippedIDs: skippedIDs
        )
    }

    private func shouldSkipDiscoveredDescriptor(
        _ descriptor: PluginDescriptor,
        replacingExisting: Bool
    ) -> Bool {
        if plugins[descriptor.id] != nil {
            return true
        }

        if descriptors[descriptor.id] != nil, !replacingExisting {
            return true
        }

        return false
    }
}
