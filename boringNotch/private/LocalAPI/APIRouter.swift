import Foundation

enum APIHTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

struct APIRequest {
    let method: APIHTTPMethod
    let path: String
    let headers: [String: String]
    let body: Data

    /// Extract path parameters from a pattern like /api/v1/plugins/{id}
    func pathParam(_ name: String) -> String? {
        pathParams[name]
    }

    /// Lazily populated by the router during matching
    var pathParams: [String: String] = [:]
}

// MARK: - Router

final class APIRouter: @unchecked Sendable, APIRouteRegistrar {
    private struct Route {
        let method: APIHTTPMethod
        let pattern: String
        let handler: APIRouteHandler
    }

    private var routes: [Route] = []
    private let lock = NSLock()

    @MainActor
    func register(method: APIHTTPMethod, path: String, handler: @escaping APIRouteHandler) {
        lock.withLock {
            // Remove existing route with same method+path
            routes.removeAll { $0.method == method && $0.pattern == path }
            routes.append(Route(method: method, pattern: path, handler: handler))
        }
    }

    @MainActor
    func unregister(path: String) {
        lock.withLock {
            routes.removeAll { $0.pattern == path }
        }
    }

    func route(_ request: APIRequest) async -> APIHTTPResponse {
        let matched: (Route, [String: String])? = lock.withLock {
            for route in routes {
                if route.method == request.method,
                   let params = matchPattern(route.pattern, against: request.path) {
                    return (route, params)
                }
            }
            return nil
        }

        guard let (route, params) = matched else {
            // Check if path exists with different method
            let pathExists = lock.withLock {
                routes.contains { matchPattern($0.pattern, against: request.path) != nil }
            }
            if pathExists {
                return .json(status: 405, APIResponseEnvelope<APIErrorData>.failure("Method not allowed"))
            }
            return .json(status: 404, APIResponseEnvelope<APIErrorData>.failure("Route not found"))
        }

        var enrichedRequest = request
        enrichedRequest.pathParams = params
        return await route.handler(enrichedRequest)
    }

    // MARK: - Pattern Matching

    /// Matches a route pattern (e.g. "/api/v1/plugins/{id}") against a request path.
    /// Returns extracted path parameters on match, nil on mismatch.
    private func matchPattern(_ pattern: String, against path: String) -> [String: String]? {
        let patternParts = pattern.split(separator: "/", omittingEmptySubsequences: true)
        let pathParts = path.split(separator: "/", omittingEmptySubsequences: true)

        guard patternParts.count == pathParts.count else { return nil }

        var params: [String: String] = [:]
        for (pat, val) in zip(patternParts, pathParts) {
            if pat.hasPrefix("{") && pat.hasSuffix("}") {
                let paramName = String(pat.dropFirst().dropLast())
                params[paramName] = String(val)
            } else if pat != val {
                return nil
            }
        }
        return params
    }
}
