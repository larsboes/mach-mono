import Foundation

struct APIResponseEnvelope<T: Encodable>: Encodable {
    let ok: Bool
    let data: T?
    let error: String?

    static func success(_ data: T? = nil) -> APIResponseEnvelope<T> {
        APIResponseEnvelope(ok: true, data: data, error: nil)
    }

    static func failure(_ message: String) -> APIResponseEnvelope<T> {
        APIResponseEnvelope(ok: false, data: nil, error: message)
    }
}

struct APIErrorData: Encodable {}

struct APIHTTPResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: Data

    init(statusCode: Int, body: Data, headers: [String: String] = [:]) {
        self.statusCode = statusCode
        self.body = body
        self.headers = headers
    }

    static func json<T: Encodable>(status: Int = 200, _ payload: T) -> APIHTTPResponse {
        let encoder = JSONEncoder()
        let data = (try? encoder.encode(payload)) ?? Data("{\"ok\":false,\"error\":\"encoding_failed\"}".utf8)
        return APIHTTPResponse(
            statusCode: status,
            body: data,
            headers: ["Content-Type": "application/json"]
        )
    }

    func serialized() -> Data {
        var allHeaders = headers
        allHeaders["Content-Length"] = "\(body.count)"
        allHeaders["Connection"] = "close"

        var response = "HTTP/1.1 \(statusCode) \(reasonPhrase(for: statusCode))\r\n"
        for (key, value) in allHeaders {
            response += "\(key): \(value)\r\n"
        }
        response += "\r\n"

        var output = Data(response.utf8)
        output.append(body)
        return output
    }

    private func reasonPhrase(for code: Int) -> String {
        switch code {
        case 101: return "Switching Protocols"
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}

struct APINotchState: Encodable {
    let phase: String
    let screen: String
    let size: APISize
}

struct APISize: Encodable {
    let width: Double
    let height: Double
}

struct APIEventPayload: Encodable {
    let type: String
    let data: [String: String]
}
