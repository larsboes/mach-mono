import Foundation
import Observation

@MainActor
@Observable
public final class TeleprompterState {
    public var text: String = "" {
        didSet {
            let engine = TeleprompterScrollEngine()
            let newText = text
            Task.detached {
                let sections = engine.parseSections(from: newText)
                await MainActor.run {
                    self.parsedSections = sections
                }
            }
        }
    }
    private var parsedSections: [TeleprompterScrollEngine.Section] = []
    public var config = TeleprompterScrollEngine.Config(
        speed: 30,
        fontSize: 16,
        pauseAtParagraph: true,
        pauseDuration: 2.0
    )

    public var textColor: PrompterColor = .white
    public var countdownDuration: Int = 3
    public let countdownState = CountdownState()
    public var scrollPosition: Double = 0

    public var isScrolling: Bool = false {
        didSet { updateTimerState() }
    }

    public var isHovering: Bool = false {
        didSet { updateTimerState() }
    }

    public var contentHeight: Double = 0

    public var isAtEnd: Bool {
        contentHeight > 0 && scrollPosition >= maxScroll
    }

    // MARK: - Timer Manager (extracted resource lifecycle)

    public let timerManager = TeleprompterTimerManager()

    /// Convenience accessor for views that read mic level.
    public var micMonitor: MicrophoneMonitor { timerManager.micMonitor }

    private var engine = TeleprompterScrollEngine()

    // MARK: - Constants

    /// Buffer pixels before content end to trigger auto-stop.
    private static let endBuffer: Double = 40
    /// Speed adjustment step.
    private static let speedStep: Double = 10
    private static let speedMin: Double = 10
    private static let speedMax: Double = 150

    private var maxScroll: Double {
        contentHeight > 0 ? (contentHeight - Self.endBuffer) : .infinity
    }

    // MARK: - Presentation Metadata

    public var progress: Double {
        guard maxScroll > 0, maxScroll != .infinity else { return 0 }
        return min(1.0, scrollPosition / maxScroll)
    }

    /// Estimated line height for section position mapping.
    private var estimatedLineHeight: Double {
        config.fontSize + 8  // fontSize + lineSpacing
    }

    public var currentSectionTitle: String? {
        return engine.currentSection(
            sections: parsedSections,
            scrollPosition: scrollPosition,
            lineHeight: estimatedLineHeight
        )?.title
    }

    public var elapsedTimeString: String {
        guard config.speed > 0 else { return "0:00" }
        return formatTime(Int(scrollPosition / config.speed))
    }

    public var remainingTimeString: String {
        guard config.speed > 0, maxScroll > 0, maxScroll != .infinity else { return "0:00" }
        return formatTime(Int(max(0, maxScroll - scrollPosition) / config.speed))
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    // MARK: - Init

    public init() {
        timerManager.onTick = { [weak self] now in
            self?.update(now: now)
        }
    }

    // MARK: - Controls

    public func toggleScrolling() {
        isScrolling.toggle()
    }

    public func reset() {
        isScrolling = false
        scrollPosition = 0
        timerManager.resetLastUpdate()
    }

    public func goHome() {
        scrollPosition = 0
        timerManager.resetLastUpdate()
    }

    public func increaseSpeed() {
        config.speed = min(config.speed + Self.speedStep, Self.speedMax)
    }

    public func decreaseSpeed() {
        config.speed = max(config.speed - Self.speedStep, Self.speedMin)
    }

    /// Start presentation: countdown first (if enabled), then begin scrolling.
    public func startPresentation() {
        if isAtEnd {
            scrollPosition = 0
        }
        countdownState.start(duration: countdownDuration) { [weak self] in
            self?.isScrolling = true
        }
    }

    /// Domain-level AI assist — delegates to the service protocol.
    public func aiAssist(action: TeleprompterAIAction, ai: any AITextGenerationService) async throws {
        guard await ai.isAvailable else {
            throw AIError.providerUnavailable(
                "No AI provider is configured for this device."
            )
        }

        let result: String
        switch action {
        case .refine:
            result = try await ai.rewrite(text, style: .professional)
        case .summarize:
            result = try await ai.summarize(text)
        case .draftIntro:
            result = try await ai.draftIntro(topic: text, durationSeconds: 60)
        }

        self.text = result
        self.reset()
    }

    public func aiAssistStream(action: TeleprompterAIAction, ai: any AITextGenerationService) async throws {
        guard await ai.isAvailable else {
            throw AIError.providerUnavailable(
                "No AI provider is configured for this device."
            )
        }

        let sourceText = text
        var generatedText = ""
        self.text = ""
        self.reset()

        let stream: AsyncThrowingStream<String, Error>
        switch action {
        case .refine:
            stream = ai.rewriteStream(sourceText, style: .professional)
        case .summarize:
            stream = ai.summarizeStream(sourceText)
        case .draftIntro:
            stream = ai.draftIntroStream(topic: sourceText, durationSeconds: 60)
        }

        do {
            for try await chunk in stream {
                generatedText += chunk
                self.text = generatedText
            }
        } catch {
            if generatedText.isEmpty {
                self.text = sourceText
            }
            throw error
        }

        self.text = generatedText
        self.reset()
    }

    // MARK: - Scroll Update

    private func update(now: Date) {
        guard isScrolling, !isHovering else { return }

        let state = TeleprompterScrollEngine.State(
            scrollPosition: scrollPosition,
            isScrolling: isScrolling,
            lastUpdate: timerManager.lastUpdate
        )

        let newPosition = engine.calculatePosition(in: state, config: config, now: now)

        if newPosition >= maxScroll {
            isScrolling = false
            scrollPosition = maxScroll
            return
        }

        scrollPosition = newPosition
    }

    // MARK: - Timer State Coordination

    private func updateTimerState() {
        if isScrolling {
            if !isHovering {
                timerManager.micMonitor.startMonitoring()
            } else {
                timerManager.micMonitor.stopMonitoring()
            }

            if !timerManager.isRunning {
                timerManager.start()
            }
        } else {
            timerManager.stop()
        }
    }
}

// MARK: - AI Action Enum

public enum TeleprompterAIAction: String, Codable, Sendable {
    case refine
    case summarize
    case draftIntro = "draft-intro"
}

// MARK: - Prompter Text Color

public enum PrompterColor: String, CaseIterable, Codable, Sendable {
    case white, warmWhite, yellow, green, cyan
}
