import Foundation

enum HTTPRequestParser {
    static func parseIfComplete(_ data: Data) -> APIRequest? {
        guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }

        let headerData = data.prefix(upTo: headerRange.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            return nil
        }

        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2,
              let method = APIHTTPMethod(rawValue: String(parts[0]))
        else {
            return nil
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let pieces = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            if pieces.count == 2 {
                headers[pieces[0].lowercased()] = pieces[1]
            }
        }

        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = headerRange.upperBound
        let expectedTotal = bodyStart + contentLength
        guard data.count >= expectedTotal else {
            return nil
        }

        let body = data.subdata(in: bodyStart..<expectedTotal)
        return APIRequest(method: method, path: String(parts[1]), headers: headers, body: body)
    }
}
