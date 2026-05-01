//
//  LyricsService+WebFetch.swift
//  boringNotch
//
//  Extracted web fetching and LRC parsing from LyricsService.
//

import Foundation

extension LyricsService {
    func fetchLyricsFromWeb(title: String, artist: String) async -> (plain: String, synced: [(time: Double, text: String)]) {
        let cleanTitle = normalizedQuery(title)
        let cleanArtist = normalizedQuery(artist)

        guard let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return ("", [])
        }

        let searchStrategies: [String] = {
            var strategies: [String] = []
            if !cleanArtist.isEmpty,
               let encodedArtist = cleanArtist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                strategies.append("https://lrclib.net/api/search?track_name=\(encodedTitle)&artist_name=\(encodedArtist)")
            }
            strategies.append("https://lrclib.net/api/search?track_name=\(encodedTitle)")
            return strategies
        }()

        for urlString in searchStrategies {
            guard let url = URL(string: urlString) else { continue }

            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 10

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    continue
                }

                if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let first = findBestMatch(in: jsonArray, title: cleanTitle, artist: cleanArtist) {
                    let plain = (first["plainLyrics"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let synced = (first["syncedLyrics"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    if !plain.isEmpty || !synced.isEmpty {
                        let resolvedPlain = plain.isEmpty ? synced : plain
                        let parsedSynced = synced.isEmpty ? [] : parseLRC(synced)
                        return (resolvedPlain, parsedSynced)
                    }
                }
            } catch {
                continue
            }
        }

        return ("", [])
    }

    func findBestMatch(in results: [[String: Any]], title: String, artist: String) -> [String: Any]? {
        guard !results.isEmpty else { return nil }
        if results.count == 1 { return results.first }

        let normalizedTitle = title.lowercased()
        let normalizedArtist = artist.lowercased()

        var bestResult: [String: Any]?
        var bestScore = 0

        for result in results {
            var score = 0

            if let resultTitle = result["trackName"] as? String {
                if resultTitle.lowercased() == normalizedTitle {
                    score += 10
                } else if resultTitle.lowercased().contains(normalizedTitle) || normalizedTitle.contains(resultTitle.lowercased()) {
                    score += 5
                }
            }

            if !normalizedArtist.isEmpty, let resultArtist = result["artistName"] as? String {
                if resultArtist.lowercased() == normalizedArtist {
                    score += 8
                } else if resultArtist.lowercased().contains(normalizedArtist) || normalizedArtist.contains(resultArtist.lowercased()) {
                    score += 4
                }
            }

            if let plain = result["plainLyrics"] as? String, !plain.isEmpty { score += 2 }
            if let synced = result["syncedLyrics"] as? String, !synced.isEmpty { score += 3 }

            if score > bestScore {
                bestScore = score
                bestResult = result
            }
        }

        return bestResult ?? results.first
    }

    func parseLRC(_ lrc: String) -> [(time: Double, text: String)] {
        var result: [(Double, String)] = []
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for lineSub in lrc.split(separator: "\n") {
            let line = String(lineSub)
            let nsLine = line as NSString

            guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else {
                continue
            }

            let minStr = nsLine.substring(with: match.range(at: 1))
            let secStr = nsLine.substring(with: match.range(at: 2))
            let msRange = match.range(at: 3)
            let msStr = msRange.location != NSNotFound ? nsLine.substring(with: msRange) : "0"

            let minutes = Double(minStr) ?? 0
            let seconds = Double(secStr) ?? 0
            let msValue = Double(msStr) ?? 0
            let msDivisor = msStr.count == 3 ? 1000.0 : 100.0
            let time = minutes * 60 + seconds + msValue / msDivisor

            let textStart = match.range.location + match.range.length
            let text = nsLine.substring(from: textStart).trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                result.append((time, text))
            }
        }

        return result.sorted { $0.0 < $1.0 }
    }

    func normalizedQuery(_ string: String) -> String {
        string
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "\u{FFFD}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
