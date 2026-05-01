//
//  NotchServiceProvider.swift
//  boringNotch
//

import Foundation
import CoreBluetooth
import Observation

/// Protocol for background polling services that can be paused to save battery
@MainActor
protocol BackgroundServiceRestartable {
    func startMonitoring()
    func stopMonitoring()
}

/// Full service provider — union of all ISP sub-protocols.
/// ServiceContainer conforms to this. Consumers should depend on the
/// narrowest sub-protocol they need (MediaServiceProvider, etc.).
/// Use NotchServiceProvider only when full access is genuinely required.
@MainActor
protocol NotchServiceProvider: MediaServiceProvider, SystemServiceProvider,
    StorageServiceProvider, UIServiceProvider, PluginExtensionServiceProvider {}

@MainActor
protocol NotesServiceProtocol: AnyObject, Observable {
    var notes: [NoteItem] { get }
    func addNote(title: String, content: String)
    func deleteNote(_ note: NoteItem)
}

@MainActor
protocol ClipboardServiceProtocol: AnyObject, Observable {
    var items: [ClipboardItem] { get }
    func startMonitoring()
    func stopMonitoring()
    func clearHistory()
    func copyToPasteboard(_ item: ClipboardItem)
    func deleteItem(_ item: ClipboardItem)
}

@MainActor
protocol BluetoothStateServiceProtocol: AnyObject, Observable {
    var connectedDevices: [BluetoothDevice] { get }
    var bluetoothState: CBManagerState { get }
    var isInitialized: Bool { get }
    func initializeBluetooth()
}

extension NotesManager: NotesServiceProtocol {}
extension ClipboardManager: ClipboardServiceProtocol {}
extension BluetoothManager: BluetoothStateServiceProtocol {}
