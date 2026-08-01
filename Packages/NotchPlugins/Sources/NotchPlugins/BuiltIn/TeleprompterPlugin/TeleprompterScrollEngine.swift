import Foundation

/// Pure logic for teleprompter scrolling.
/// No dependencies on SwiftUI or AppKit.
public struct TeleprompterScrollEngine: Sendable {
    public struct Config: Codable, Sendable {
        public var speed: Double  // lines per minute or pixels per second? Let's say pixels per second.
        public var fontSize: Double
        public var pauseAtParagraph: Bool
        public var pauseDuration: TimeInterval

        public init(speed: Double, fontSize: Double, pauseAtParagraph: Bool, pauseDuration: TimeInterval) {
            self.speed = speed
            self.fontSize = fontSize
            self.pauseAtParagraph = pauseAtParagraph
            self.pauseDuration = pauseDuration
        }
    }

    public struct State: Codable, Sendable {
        public var scrollPosition: Double
        public var isScrolling: Bool
        public var lastUpdate: Date?

        public init(scrollPosition: Double, isScrolling: Bool, lastUpdate: Date?) {
            self.scrollPosition = scrollPosition
            self.isScrolling = isScrolling
            self.lastUpdate = lastUpdate
        }
    }

    public init() {}

    /// Calculate current scroll position based on time elapsed.
    public func calculatePosition(in state: State, config: Config, now: Date = Date()) -> Double {
        guard state.isScrolling, let lastUpdate = state.lastUpdate else {
            return state.scrollPosition
        }

        let elapsed = now.timeIntervalSince(lastUpdate)
        return state.scrollPosition + (config.speed * elapsed)
    }

    // MARK: - Section Parsing

    public struct Section: Sendable {
        public let title: String
        public let lineIndex: Int

        public init(title: String, lineIndex: Int) {
            self.title = title
            self.lineIndex = lineIndex
        }
    }

    /// Parse text into sections using "##" as markers, tracking line positions.
    public func parseSections(from text: String) -> [Section] {
        text.components(separatedBy: .newlines)
            .enumerated()
            .compactMap { index, line in
                guard line.hasPrefix("##") else { return nil }
                return Section(
                    title: line.replacingOccurrences(of: "##", with: "").trimmingCharacters(in: .whitespaces),
                    lineIndex: index
                )
            }
    }

    /// Find the current section based on scroll position and estimated line height.
    public func currentSection(
        sections: [Section],
        scrollPosition: Double,
        lineHeight: Double
    ) -> Section? {
        guard lineHeight > 0 else { return nil }
        let currentLine = Int(scrollPosition / lineHeight)
        return sections.last { $0.lineIndex <= currentLine }
    }
}
