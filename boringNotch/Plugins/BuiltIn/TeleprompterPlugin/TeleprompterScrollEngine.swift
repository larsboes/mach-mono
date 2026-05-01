import Foundation

/// Pure logic for teleprompter scrolling.
/// No dependencies on SwiftUI or AppKit.
struct TeleprompterScrollEngine: Sendable {
    struct Config: Codable, Sendable {
        var speed: Double // lines per minute or pixels per second? Let's say pixels per second.
        var fontSize: Double
        var pauseAtParagraph: Bool
        var pauseDuration: TimeInterval
    }
    
    struct State: Codable, Sendable {
        var scrollPosition: Double
        var isScrolling: Bool
        var lastUpdate: Date?
    }
    
    /// Calculate current scroll position based on time elapsed.
    func calculatePosition(in state: State, config: Config, now: Date = Date()) -> Double {
        guard state.isScrolling, let lastUpdate = state.lastUpdate else {
            return state.scrollPosition
        }
        
        let elapsed = now.timeIntervalSince(lastUpdate)
        return state.scrollPosition + (config.speed * elapsed)
    }
    
    // MARK: - Section Parsing

    struct Section: Sendable {
        let title: String
        let lineIndex: Int
    }

    /// Parse text into sections using "##" as markers, tracking line positions.
    func parseSections(from text: String) -> [Section] {
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
    func currentSection(
        sections: [Section],
        scrollPosition: Double,
        lineHeight: Double
    ) -> Section? {
        guard lineHeight > 0 else { return nil }
        let currentLine = Int(scrollPosition / lineHeight)
        return sections.last { $0.lineIndex <= currentLine }
    }
}
