import Foundation
import Security

/// Bearer token authentication middleware using the Keychain.
/// Thread-safe — token loaded once at init, cached in memory.
final class APIAuthMiddleware: @unchecked Sendable {
    private let account = "me.theboringteam.boringnotch.api.token"
    private let lock = NSLock()
    private var cachedToken: String?

    init() {
        self.cachedToken = Self.loadOrCreateToken(account: account)
    }

    /// Authenticate a request. Returns `true` if valid, `false` if rejected.
    ///
    /// Behavior:
    /// - If no token exists in Keychain (creation failed): rejects all authed requests.
    /// - If Authorization header is missing: rejects (caller must decide when to call this).
    /// - If token matches: allows.
    func authenticate(_ request: APIRequest) -> Bool {
        let validToken: String? = lock.withLock { cachedToken }

        guard let validToken else {
            // Keychain failure — deny by default (secure fallback).
            return false
        }

        guard let authHeader = request.headers["authorization"] else {
            return false
        }

        return authHeader == "Bearer \(validToken)"
    }

    /// The current API token for display in settings / CLI setup.
    var currentToken: String? {
        lock.withLock { cachedToken }
    }

    func resetToken() {
        let newToken = UUID().uuidString
        if Self.saveToken(newToken, account: account) {
            lock.withLock { cachedToken = newToken }
        }
    }

    // MARK: - Keychain Helpers

    private static func loadOrCreateToken(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            return token
        }

        let newToken = UUID().uuidString
        return saveToken(newToken, account: account) ? newToken : nil
    }

    private static func saveToken(_ token: String, account: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }
}
