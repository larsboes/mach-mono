import Foundation

public struct APIResponseEnvelope<T: Encodable>: Encodable {
    public let ok: Bool
    public let data: T?
    public let error: String?

    public init(ok: Bool, data: T?, error: String?) {
        self.ok = ok
        self.data = data
        self.error = error
    }

    public static func success(_ data: T? = nil) -> APIResponseEnvelope<T> {
        APIResponseEnvelope(ok: true, data: data, error: nil)
    }

    public static func failure(_ message: String) -> APIResponseEnvelope<T> {
        APIResponseEnvelope(ok: false, data: nil, error: message)
    }
}

public struct APIErrorData: Encodable {
    public init() {}
}

public struct APIHTTPResponse {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data

    public init(statusCode: Int, body: Data, headers: [String: String] = [:]) {
        self.statusCode = statusCode
        self.body = body
        self.headers = headers
    }

    public static func json<T: Encodable>(status: Int = 200, _ payload: T) -> APIHTTPResponse {
        let encoder = JSONEncoder()
        let data = (try? encoder.encode(payload)) ?? Data("{\"ok\":false,\"error\":\"encoding_failed\"}".utf8)
        return APIHTTPResponse(
            statusCode: status,
            body: data,
            headers: ["Content-Type": "application/json"]
        )
    }

    public func serialized() -> Data {
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

public struct APINotchState: Encodable {
    public let phase: String
    public let screen: String
    public let size: APISize

    public init(phase: String, screen: String, size: APISize) {
        self.phase = phase
        self.screen = screen
        self.size = size
    }
}

public struct APISize: Encodable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct APIEventPayload: Encodable {
    public let type: String
    public let data: [String: String]

    public init(type: String, data: [String: String]) {
        self.type = type
        self.data = data
    }
}
