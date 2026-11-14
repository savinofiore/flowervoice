import Foundation

struct CodexCredentials {
    let accessToken: String
    let accountId: String
}

enum CodexAuthError: LocalizedError {
    case missingAuthFile
    case notChatGPTLogin
    case refreshFailed(Int)

    var errorDescription: String? {
        switch self {
        case .missingAuthFile: "~/.codex/auth.json not found: run `codex login`."
        case .notChatGPTLogin: "Codex is not logged in with a ChatGPT account."
        case .refreshFailed(let status): "Codex token refresh failed (HTTP \(status)): run `codex login`."
        }
    }
}

/// Reads the ChatGPT tokens that the Codex CLI stores, refreshing them the same way Codex does.
/// Refreshed tokens are written back so Codex keeps working (refresh tokens rotate).
actor CodexAuth {
    private static let CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"
    private static let TOKEN_URL = URL(string: "https://auth.openai.com/oauth/token")!
    private static let REFRESH_MARGIN_SECONDS: TimeInterval = 300

    private let authFile = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex/auth.json")

    func credentials() async throws -> CodexCredentials {
        let credentials = try parseCredentials(try readAuthJSON())
        guard isExpiringSoon(credentials.accessToken) else { return credentials }
        return try await refresh()
    }

    func refresh() async throws -> CodexCredentials {
        var json = try readAuthJSON()
        guard var tokens = json["tokens"] as? [String: Any],
              let refreshToken = tokens["refresh_token"] as? String else { throw CodexAuthError.notChatGPTLogin }
        let fresh = try await requestNewTokens(refreshToken: refreshToken)
        tokens.merge(fresh) { _, new in new }
        json["tokens"] = tokens
        json["last_refresh"] = ISO8601DateFormatter().string(from: Date())
        try writeAuthJSON(json)
        return try parseCredentials(json)
    }

    private func requestNewTokens(refreshToken: String) async throws -> [String: Any] {
        var request = URLRequest(url: Self.TOKEN_URL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_id": Self.CLIENT_ID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "scope": "openid profile email",
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200, let body = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CodexAuthError.refreshFailed(status)
        }
        return body.filter { ["access_token", "refresh_token", "id_token"].contains($0.key) }
    }

    private func readAuthJSON() throws -> [String: Any] {
        guard let data = try? Data(contentsOf: authFile),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CodexAuthError.missingAuthFile
        }
        return json
    }

    private func writeAuthJSON(_ json: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: authFile, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: authFile.path)
    }

    private func parseCredentials(_ json: [String: Any]) throws -> CodexCredentials {
        guard let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              let accountId = tokens["account_id"] as? String else { throw CodexAuthError.notChatGPTLogin }
        return CodexCredentials(accessToken: accessToken, accountId: accountId)
    }

    private func isExpiringSoon(_ jwt: String) -> Bool {
        guard let expiry = JWTClaims.expiry(of: jwt) else { return false }
        return expiry.timeIntervalSinceNow < Self.REFRESH_MARGIN_SECONDS
    }
}

enum JWTClaims {
    static func expiry(of jwt: String) -> Date? {
        let parts = jwt.split(separator: ".")
        guard parts.count > 1 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = claims["exp"] as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: exp)
    }
}
