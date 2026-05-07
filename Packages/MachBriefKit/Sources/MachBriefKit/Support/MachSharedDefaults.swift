import Foundation

/// Shared UserDefaults suite used by all mach apps.
/// Falls back to .standard in contexts where the App Group is not provisioned (tests, simulator).
public enum MachSharedDefaults {
    public static let suiteName = "group.com.larsboes.mach"

    public static var suite: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
