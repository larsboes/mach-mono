// HealthReceiverStub — machHealth H0
// Minimal LAN receiver: listens on :8787, advertises Bonjour `_machhealth._tcp`,
// accepts HTTP POSTs (schema-v1 JSON or raw Shortcuts payloads), appends
// everything to ~/machhealth/inbox.jsonl, and — the actual point of H0 —
// tracks per-metric delivery latency (sample `end` time → arrival) so the
// PLAN-machHealth latency table gets real numbers.
//
// Deliberately crude HTTP/1.1 parsing (single request per connection,
// Content-Length required). No auth — H0 runs on a trusted LAN; pairing/token
// arrives with HealthExportKit (H1).

import Foundation
import Network

let port: UInt16 = 8787

// MARK: - Storage
let inboxDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("machhealth")
try? FileManager.default.createDirectory(at: inboxDir, withIntermediateDirectories: true)
let inboxURL = inboxDir.appendingPathComponent("inbox.jsonl")

func appendToInbox(_ line: String) {
    guard let data = (line + "\n").data(using: .utf8) else { return }
    if let handle = try? FileHandle(forWritingTo: inboxURL) {
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    } else {
        try? data.write(to: inboxURL)
    }
}

// MARK: - Date parsing (Shortcuts and ISO8601 variants)
let isoFrac = ISO8601DateFormatter()
isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
let isoPlain = ISO8601DateFormatter()
func parseDate(_ s: String) -> Date? {
    isoFrac.date(from: s) ?? isoPlain.date(from: s)
}

// MARK: - Latency stats (H0's purpose)
var latenciesByType: [String: [Double]] = [:]
var postCount = 0

func median(_ xs: [Double]) -> Double {
    let s = xs.sorted(); let n = s.count
    return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
}
func p90(_ xs: [Double]) -> Double {
    let s = xs.sorted()
    return s[min(s.count - 1, Int(Double(s.count) * 0.9))]
}
func fmtMin(_ seconds: Double) -> String {
    String(format: "%.1f min", seconds / 60)
}

func printStats() {
    guard !latenciesByType.isEmpty else { return }
    print("── latency table (paste into PLAN-machHealth.md when ≥1 week) ──")
    for (type, ls) in latenciesByType.sorted(by: { $0.key < $1.key }) {
        print("  \(type): median \(fmtMin(median(ls))), p90 \(fmtMin(p90(ls))), n=\(ls.count)")
    }
}

// MARK: - Payload handling
func handle(body: Data, arrivedAt: Date) {
    postCount += 1
    let raw = String(data: body, encoding: .utf8) ?? "<non-utf8 \(body.count) bytes>"
    appendToInbox(#"{"arrivedAt":"\#(isoFrac.string(from: arrivedAt))","raw":\#(raw)}"#)

    guard
        let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
        let samples = json["samples"] as? [[String: Any]]
    else {
        print("[\(postCount)] non-schema payload (\(body.count) bytes) — logged raw")
        return
    }

    let device = json["device"] as? String ?? "?"
    for sample in samples {
        let type = sample["type"] as? String ?? "unknown"
        let value = sample["value"] ?? "?"
        var latencyNote = ""
        if let endStr = sample["end"] as? String, let end = parseDate(endStr) {
            let latency = arrivedAt.timeIntervalSince(end)
            if latency >= 0 && latency < 7 * 24 * 3600 {
                latenciesByType[type, default: []].append(latency)
                latencyNote = " (latency \(fmtMin(latency)))"
            }
        }
        print("[\(postCount)] \(device) \(type) = \(value)\(latencyNote)")
    }
    if postCount % 10 == 0 { printStats() }
}

// MARK: - Crude HTTP server over NWListener
func serve(_ connection: NWConnection) {
    var buffer = Data()

    func respondAndClose() {
        let bodyJSON = #"{"ok":true}"#
        let response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n"
            + "Content-Length: \(bodyJSON.utf8.count)\r\nConnection: close\r\n\r\n" + bodyJSON
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { data, _, isComplete, error in
            if let data { buffer.append(data) }

            if let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerText = String(data: buffer.subdata(in: 0..<headerEnd.lowerBound), encoding: .utf8) ?? ""
                let contentLength = headerText
                    .split(separator: "\r\n")
                    .first { $0.lowercased().hasPrefix("content-length:") }
                    .flatMap { Int($0.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) } ?? 0
                let bodyStart = headerEnd.upperBound
                if buffer.count - bodyStart >= contentLength {
                    let body = buffer.subdata(in: bodyStart..<(bodyStart + contentLength))
                    handle(body: body, arrivedAt: Date())
                    respondAndClose()
                    return
                }
            }
            if isComplete || error != nil { connection.cancel(); return }
            receiveLoop()
        }
    }

    connection.start(queue: .main)
    receiveLoop()
}

// MARK: - Boot
do {
    let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
    listener.service = NWListener.Service(name: "machHealth", type: "_machhealth._tcp")
    listener.newConnectionHandler = serve
    listener.stateUpdateHandler = { state in
        if case .failed(let err) = state { print("listener failed: \(err)"); exit(1) }
    }
    listener.start(queue: .main)
    print("""
    machHealth receiver listening on :\(port) (Bonjour: _machhealth._tcp)
    Inbox: \(inboxURL.path)
    POST JSON to http://<this-mac>.local:\(port)/ — Ctrl-C to stop.
    """)
    RunLoop.main.run()
} catch {
    print("failed to start listener: \(error)")
    exit(1)
}
