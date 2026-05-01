import Foundation

typealias APIRouteHandler = @Sendable (APIRequest) async -> APIHTTPResponse

/// Protocol for route registration — plugins use this to add/remove API endpoints.
@MainActor protocol APIRouteRegistrar: AnyObject {
    func register(method: APIHTTPMethod, path: String, handler: @escaping APIRouteHandler)
    func unregister(path: String)
}
