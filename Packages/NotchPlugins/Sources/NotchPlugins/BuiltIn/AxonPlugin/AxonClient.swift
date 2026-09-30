//
//  AxonClient.swift
//  NotchAxonPlugin
//
//  High-performance local loopback client for Axon daemon microservices.
//

import Foundation

@MainActor
@Observable
public final class AxonClient {

    // Default capability ports
    public var statusPort: Int = 8082
    public var calendarPort: Int = 8087
    public var commsPort: Int = 8083
    public var transitPort: Int = 3000
    public var soundscapePort: Int = 8088
    public var macmonPort: Int = 9911

    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 3.0
        config.timeoutIntervalForResource = 5.0
        self.session = URLSession(configuration: config)
    }

    // MARK: - Health & System Status

    public func fetchHealth() async -> AxonHealthStatus? {
        guard let url = URL(string: "http://127.0.0.1:\(statusPort)/health") ??
                        URL(string: "http://127.0.0.1:\(statusPort)/axon-status/api/health") else {
            return nil
        }
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            if let decoded = try? JSONDecoder().decode(AxonHealthStatus.self, from: data) {
                return decoded
            }
            return AxonHealthStatus(status: "ok")
        } catch {
            return nil
        }
    }

    // MARK: - Calendar & Horizon

    public func fetchCommitments() async -> [AxonCommitment] {
        guard let url = URL(string: "http://127.0.0.1:\(calendarPort)/api/calendar/entries") ??
                        URL(string: "http://127.0.0.1:\(calendarPort)/calendar/api/entries") else {
            return fallbackCommitments()
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return fallbackCommitments()
            }

            struct RawEntry: Decodable {
                let id: String
                let title: String
                let starts_at: String?
                let ends_at: String?
                let location: String?
                let all_day: Bool?
                let commitment: String?
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let fallbackFormatter = ISO8601DateFormatter()
            fallbackFormatter.formatOptions = [.withInternetDateTime]

            let entries = try JSONDecoder().decode([RawEntry].self, from: data)
            let parsed = entries.compactMap { entry -> AxonCommitment? in
                guard let startStr = entry.starts_at,
                      let startDate = formatter.date(from: startStr) ?? fallbackFormatter.date(from: startStr) else {
                    return nil
                }
                let endDate = (entry.ends_at.flatMap { formatter.date(from: $0) ?? fallbackFormatter.date(from: $0) }) ?? startDate.addingTimeInterval(3600)
                return AxonCommitment(
                    id: entry.id,
                    title: entry.title,
                    start: startDate,
                    end: endDate,
                    location: entry.location,
                    isAllDay: entry.all_day ?? false,
                    category: entry.commitment
                )
            }
            return parsed.sorted(by: { $0.start < $1.start })
        } catch {
            return fallbackCommitments()
        }
    }

    // MARK: - Ingest URL or Text

    public func ingest(content: String) async throws -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(commsPort)/comms/api/ingest") ??
                        URL(string: "http://127.0.0.1:\(commsPort)/api/ingest") else {
            return false
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["url": content, "source": "mac_notch"]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return false
        }
        return true
    }

    // MARK: - Fallback / Offline Demo Data

    public func fallbackCommitments() -> [AxonCommitment] {
        let now = Date()
        return [
            AxonCommitment(
                id: "axon-comm-1",
                title: "Axon Architecture & Triage Review",
                start: now.addingTimeInterval(1200), // +20 mins
                end: now.addingTimeInterval(4800),
                location: "Berlin Studio",
                isAllDay: false,
                category: "committed"
            ),
            AxonCommitment(
                id: "axon-comm-2",
                title: "Transit Departure: ICE 1004",
                start: now.addingTimeInterval(7200), // +2 hours
                end: now.addingTimeInterval(14400),
                location: "Berlin Hbf",
                isAllDay: false,
                category: "planned"
            ),
            AxonCommitment(
                id: "axon-comm-3",
                title: "Soundscape Ambient Recording",
                start: now.addingTimeInterval(18000), // +5 hours
                end: now.addingTimeInterval(21600),
                location: "Studio 2",
                isAllDay: false,
                category: "possible"
            )
        ]
    }
}
