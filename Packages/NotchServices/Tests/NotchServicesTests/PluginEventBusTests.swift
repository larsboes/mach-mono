import XCTest
@testable import NotchServices

@MainActor
final class PluginEventBusTests: XCTestCase {
    func testSubscribeToEventTypeOnlyReceivesMatchingEventPayloads() {
        let bus = PluginEventBus()
        var received: [Double] = []

        let cancellable = bus.subscribe(to: BatteryStateChangedEvent.self) { event in
            received.append(event.level)
        }

        bus.emit(GenericPluginEvent(type: .batteryLevelChanged, sourcePluginId: "battery"))
        bus.emit(
            BatteryStateChangedEvent(
                level: 0.66,
                isCharging: true,
                levelChanged: true
            )
        )

        XCTAssertEqual(received, [0.66])
        cancellable.cancel()
    }

    func testSubscribeFromPluginIdOnlyReceivesEventsFromMatchingPlugin() {
        let bus = PluginEventBus()
        var received: [PluginEventType] = []

        let cancellable = bus.subscribe(from: "calendar") { event in
            received.append(event.type)
        }

        bus.emit(GeneralEvent(type: .calendarEventStarted, sourcePluginId: "calendar"))
        bus.emit(GeneralEvent(type: .calendarEventEnded, sourcePluginId: "music"))

        XCTAssertEqual(received, [.calendarEventStarted])
        cancellable.cancel()
    }

    func testSubscribeToTypeReceivesMatchingType() {
        let bus = PluginEventBus()
        var received = 0

        let cancellable = bus.subscribe(toType: .batteryChargingStateChanged) { _ in
            received += 1
        }

        bus.emit(GeneralEvent(type: .batteryChargingStateChanged, sourcePluginId: "battery"))
        bus.emit(GeneralEvent(type: .batteryLevelChanged, sourcePluginId: "battery"))

        XCTAssertEqual(received, 1)
        cancellable.cancel()
    }

    func testSubscriptionCancellationStopsFurtherEvents() {
        let bus = PluginEventBus()
        var received = 0

        let cancellable = bus.subscribe(toType: .notchOpened) { _ in
            received += 1
        }

        cancellable.cancel()
        bus.emit(GeneralEvent(type: .notchOpened, sourcePluginId: "system"))

        XCTAssertEqual(received, 0)
    }
}

private struct GeneralEvent: PluginEvent {
    let type: PluginEventType
    let sourcePluginId: String
    let timestamp = Date()
}
