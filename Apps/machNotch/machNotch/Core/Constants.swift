//
//  Constants.swift
//  machNotch
//
//  App infrastructure constants — paths, notification names, data types.
//

import Defaults
import Foundation

// MARK: - File System Paths
let documentsDirectory =
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    ?? FileManager.default.temporaryDirectory
let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.machnotch.unknown"
let appVersion =
    "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))"

let temporaryDirectory =
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    ?? FileManager.default.temporaryDirectory
let spacing: CGFloat = 16

// Removed duplicate BluetoothDeviceIconMapping (now defined in NotchCore)


