import Foundation
import SwiftUI

/// Bluetooth service
/// Note: Uses existing BluetoothDevice from managers/BluetoothManager.swift
@MainActor
protocol BluetoothServiceProtocol: Observable {
    var isEnabled: Bool { get }
    var connectedDevices: [BluetoothDevice] { get }

    func toggleBluetooth() async
}
