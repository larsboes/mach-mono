//
//  NotchViewModel.swift — machNotch (mach-mono)
//  Orchestrates controllers + observers; phase transitions via NotchPhaseCoordinator (NotchPhaseDelegate).
//  Contract: phase APIs delegate to phaseCoordinator; syncAnimationState skips transitions;
//  syncBackgroundServices gates restartables; drag shelf wiring in attachShelfDragBehavior.

import Combine
import SwiftUI

@MainActor
@Observable class NotchViewModel: NotchPhaseDelegate {

    // MARK: - Composition

    let coordinator: any ViewCoordinating
    private let fullscreenDetector: FullscreenMediaDetector
    let settings: NotchViewModelSettings
    let displaySettings: any DisplaySettings

    let hoverController: NotchHoverController
    let sizeCalculator: NotchSizeCalculator
    let observerSetup: NotchObserverManager
    let phaseCoordinator = NotchPhaseCoordinator()

    let animation: Animation = NotchAnimations.animation

    var gestureCoordinator = NotchGestureCoordinator()

    let services: any NotchServiceProvider
    var shelfService: ShelfServiceProtocol?

    let uiContext = PluginUIContext()

    weak var window: NSWindow?

    // MARK: - Navigation (per-screen; multi-display independent)

    var currentView: NotchViews = .home

    func navigate(to view: NotchViews) {
        // Calendar onHover won't fire false when the home view leaves the hierarchy,
        // so the sticky isHoveringCalendar blocks swipe-up-to-close on other views.
        isHoveringCalendar = false
        withAnimation(.smooth) {
            self.currentView = view
        }
    }

    // MARK: - Phase surface

    var phase: NotchPhase { phaseCoordinator.phase }

    var notchState: NotchState {
        phase.isVisible ? .open : .closed
    }

    func open(initialVelocity: CGFloat = 0) {
        phaseCoordinator.open(initialVelocity: initialVelocity)
    }

    func close(force: Bool = false) {
        phaseCoordinator.close(force: force)
    }

    func closeHello() {
        phaseCoordinator.closeHello()
    }

    func interactiveScrub(progress: CGFloat) {
        phaseCoordinator.interactiveScrub(progress: progress)
    }

    func cancelInteractiveScrub() {
        phaseCoordinator.cancelInteractiveScrub()
    }

    func syncBackgroundServices() {
        let restartables: [any BackgroundServiceRestartable] = [
            services.battery as? BackgroundServiceRestartable,
            // Only monitor Bluetooth when the sneakpeek feature is enabled —
            // avoids the system permission prompt for users who don't use it.
            settings.enableBluetoothSneakPeek ? services.bluetoothManager as? BackgroundServiceRestartable : nil,
        ].compactMap { $0 }

        for service in restartables {
            if phase.isVisible {
                service.startMonitoring()
            } else {
                service.stopMonitoring()
            }
        }
    }

    // MARK: - Animation progress (shell vs content)

    var contentRevealProgress: CGFloat = 0
    var shellAnimationProgress: CGFloat = 0

    // MARK: - Drag / drop targeting

    var dragDetectorTargeting: Bool {
        get { uiContext.dragDetectorTargeting }
        set { uiContext.dragDetectorTargeting = newValue }
    }
    
    var generalDropTargeting: Bool = false
    
    var dropZoneTargeting: Bool {
        get { uiContext.dropZoneTargeting }
        set { uiContext.dropZoneTargeting = newValue }
    }
    
    var dropEvent: Bool {
        get { uiContext.dropEvent }
        set { uiContext.dropEvent = newValue }
    }

    var anyDropZoneTargeting: Bool {
        dropZoneTargeting || dragDetectorTargeting || generalDropTargeting
    }

    // MARK: - Closed-notch presentation

    var hideOnClosed: Bool = true
    @ObservationIgnored var hideOnClosedDebounceTask: Task<Void, Never>?

    var closedEarsActive: Bool = false
    @ObservationIgnored var earsDebounceTask: Task<Void, Never>?
    @ObservationIgnored var earsTrackingTask: Task<Void, Never>?
    var earsCancellables = Set<AnyCancellable>()

    var pluginPreferredHeight: CGFloat?

    var edgeAutoOpenActive: Bool = false
    var isHoveringCalendar: Bool = false

    var isBatteryPopoverActive: Bool = false {
        didSet {
            hoverController.isBatteryPopoverActive = isBatteryPopoverActive
        }
    }

    var backgroundImage: NSImage?

    var screenUUID: String? {
        didSet {
            updateNotchSize()
            hoverController.updateHoverZone(screenUUID: screenUUID)
        }
    }

    var notchSize: CGSize {
        get { sizeCalculator.notchSize }
        set { sizeCalculator.notchSize = newValue }
    }

    var closedNotchSize: CGSize {
        get { sizeCalculator.closedNotchSize }
        set { sizeCalculator.closedNotchSize = newValue }
    }

    var inactiveNotchSize: CGSize {
        get { sizeCalculator.inactiveNotchSize }
        set { sizeCalculator.inactiveNotchSize = newValue }
    }

    var isCameraExpanded: Bool = false
    var isRequestingAuthorization: Bool = false

    var notificationCancellables = Set<AnyCancellable>()
    @ObservationIgnored var sizeObserverTask: Task<Void, Never>?

    var isHoveringNotch: Bool {
        hoverController.isHoveringNotch
    }

    deinit {
        hideOnClosedDebounceTask?.cancel()
        earsDebounceTask?.cancel()
        earsTrackingTask?.cancel()
        sizeObserverTask?.cancel()
    }

    // MARK: - Initialization

    init(
        screenUUID: String? = nil,
        coordinator: any ViewCoordinating,
        detector: FullscreenMediaDetector,
        services: any NotchServiceProvider,
        settings: NotchViewModelSettings? = nil,
        displaySettings: any DisplaySettings
    ) {
        self.coordinator = coordinator
        self.fullscreenDetector = detector
        self.services = services
        self.settings = settings ?? DefaultNotchViewModelSettings(source: MockNotchSettings())
        self.displaySettings = displaySettings

        self.hoverController = NotchHoverController(
            settings: self.settings,
            displaySettings: displaySettings
        )
        self.sizeCalculator = NotchSizeCalculator(
            settings: self.settings,
            displaySettings: displaySettings
        )
        self.observerSetup = NotchObserverManager(
            settings: self.settings,
            detector: detector
        )

        self.phaseCoordinator.delegate = self

        let sharingBlocksClose: @MainActor () -> Bool = { [weak self] in
            self?.services.sharing.preventNotchClose ?? false
        }
        hoverController.shouldPreventClose = sharingBlocksClose

        configureHoverCallbacks()
        attachShelfDragBehavior()

        self.screenUUID = screenUUID

        sizeCalculator.notchSize = getClosedNotchSize(
            settings: displaySettings,
            screenUUID: screenUUID
        )
        sizeCalculator.closedNotchSize = sizeCalculator.notchSize
        sizeCalculator.inactiveNotchSize = getInactiveNotchSize(
            settings: displaySettings,
            screenUUID: screenUUID
        )
        
        uiContext.notchSize = sizeCalculator.notchSize
        uiContext.closedNotchSize = sizeCalculator.closedNotchSize
        uiContext.notchState = notchState
        uiContext.phase = phase

        hoverController.updateHoverZone(screenUUID: screenUUID)

        setupDetectorObserver()
        setupBackgroundImageObserver()
        setupSizeObserver()
        setupIntentObservers()
        setupTabResetObserver()
        setupEarsObserver()
    }

    @MainActor
    convenience init() {
        let mockSettings = MockNotchSettings()
        let mockServices = ServiceContainer(
            eventBus: PluginEventBus(),
            settings: mockSettings
        )
        self.init(
            coordinator: NotchViewCoordinator(
                settings: mockSettings,
                xpcHelper: XPCHelperClient.shared
            ),
            detector: FullscreenMediaDetector(
                musicService: mockServices.music,
                settings: mockSettings
            ),
            services: mockServices,
            displaySettings: mockSettings
        )
    }

    private func attachShelfDragBehavior() {
        services.dragDrop.onDragEntersNotchRegion = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.dragDetectorTargeting = true
                self.open()
                self.currentView = .shelf
            }
        }

        services.dragDrop.onDragExitsNotchRegion = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.dragDetectorTargeting = false
            }
        }

        services.dragDrop.startMonitoring()
    }

}
