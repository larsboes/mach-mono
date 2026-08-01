import Foundation
import Observation

@MainActor
public protocol NotchSettings: AnyObject, Observable, CoordinatorSettings, BatterySettings, GestureSettings,
    WidgetSettings, NotchCalendarSettings, NotificationSettings, BluetoothSettings, LocalAISettings
{}
