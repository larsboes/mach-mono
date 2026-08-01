//
//  ShelfItem.swift
//  NotchCore
//

import Foundation

public enum ShelfItemKind: Codable, Equatable, Sendable {
    case file(bookmark: Data)
    case text(string: String)
    case link(url: URL)

    enum CodingKeys: String, CodingKey { case type, value }

    enum KindTag: String, Codable { case file, text, link }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(KindTag.self, forKey: .type)
        switch type {
        case .file:
            let data = try container.decode(Data.self, forKey: .value)
            self = .file(bookmark: data)
        case .text:
            self = .text(string: try container.decode(String.self, forKey: .value))
        case .link:
            self = .link(url: try container.decode(URL.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .file(let bookmark):
            try container.encode(KindTag.file, forKey: .type)
            try container.encode(bookmark, forKey: .value)
        case .text(let string):
            try container.encode(KindTag.text, forKey: .type)
            try container.encode(string, forKey: .value)
        case .link(let url):
            try container.encode(KindTag.link, forKey: .type)
            try container.encode(url, forKey: .value)
        }
    }
}

public struct ShelfItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let kind: ShelfItemKind
    public let isTemporary: Bool
    
    public init(id: UUID = UUID(), kind: ShelfItemKind, isTemporary: Bool = false) {
        self.id = id
        self.kind = kind
        self.isTemporary = isTemporary
    }

    public var displayName: String {
        switch kind {
        case .file(let bookmarkData):
            let bookmark = Bookmark(data: bookmarkData)
            guard let resolvedURL = bookmark.resolvedURL else { return "" }

            // Check for stored data files (text blocks, weblocs, etc.) to provide friendly names
            if resolvedURL.pathExtension.lowercased() == "json" && resolvedURL.path.contains("TextBlocks") {
                do {
                    let data = try Data(contentsOf: resolvedURL)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    struct TextBlockData: Codable {
                        let content: String
                        let title: String?
                        var displayTitle: String {
                            if let title = title, !title.isEmpty {
                                return title
                            }
                            let firstLine = content.components(separatedBy: .newlines).first ?? content
                            if firstLine.count > 50 {
                                return String(firstLine.prefix(47)) + "..."
                            }
                            return firstLine
                        }
                    }
                    if let textData = try? decoder.decode(TextBlockData.self, from: data) {
                        return textData.displayTitle
                    }
                } catch {
                    // Fall through to default naming
                }
            } else if resolvedURL.pathExtension.lowercased() == "webloc" && resolvedURL.path.contains("WebLocs") {
                do {
                    let data = try Data(contentsOf: resolvedURL)
                    if let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
                        as? [String: Any],
                        let urlString = plist["URL"] as? String
                    {
                        let title = plist["Title"] as? String
                        return title ?? urlString
                    }
                } catch {
                    // Fall through to default naming
                }
            }
            return (try? resolvedURL.resourceValues(forKeys: [.localizedNameKey]).localizedName)
                ?? resolvedURL.lastPathComponent
        case .text(let string):
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case .link(let url):
            let s = url.absoluteString
            if s.hasPrefix("https://") {
                return String(s.dropFirst("https://".count))
            } else if s.hasPrefix("http://") {
                return String(s.dropFirst("http://".count))
            } else {
                return s
            }
        }
    }

    public var fileURL: URL? {
        guard case let .file(bookmarkData) = kind else { return nil }
        return Bookmark(data: bookmarkData).resolvedURL
    }

    public var URL: URL? {
        switch kind {
        case .file(let bookmarkData):
            return Bookmark(data: bookmarkData).resolvedURL
        case .link(let url):
            return url
        case .text:
            return nil
        }
    }
}

// MARK: - Identity key for deduplication
public extension ShelfItem {
    var identityKey: String {
        switch kind {
        case .file(let bookmarkData):
            if let url = Bookmark(data: bookmarkData).resolvedURL {
                return "file://" + url.standardizedFileURL.path
            }
            return "file://missing/" + bookmarkData.base64EncodedString()
        case .link(let u):
            return "link://" + u.absoluteString
        case .text(let s):
            return "text://" + s
        }
    }
}

// MARK: - Private helpers
public extension ShelfItemKind {
    var iconSymbolName: String {
        switch self {
        case .file:
            return "questionmark.circle"
        case .text:
            return "text.justifyleft"
        case .link:
            return "link"
        }
    }
}
