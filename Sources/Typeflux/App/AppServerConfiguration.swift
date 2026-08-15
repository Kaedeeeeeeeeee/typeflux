import Foundation

enum AppServerConfiguration {
    private static let defaultBaseURLs = ["https://api.typeflux.app", "https://typeflux-api.aicode.cc"]
    private static let defaultGoogleCloudOAuthClientID = "86325451552-drgdrf01ffjo0on25a1psmg4mpvlo8gi.apps.googleusercontent.com"

    private static func configuredValue(
        environmentKey: String,
        infoPlistKey: String,
        default defaultValue: String
    ) -> String {
        if let value = ProcessInfo.processInfo.environment[environmentKey], !value.isEmpty {
            return value
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String, !value.isEmpty {
            return value
        }
        return defaultValue
    }

    /// Ordered list of application service base URLs.
    /// Sources, in priority order:
    /// 1. `TYPEFLUX_API_URLS` env var or Info.plist key — comma-separated list
    /// 2. `TYPEFLUX_API_URL` env var or Info.plist key — single URL (legacy)
    /// 3. Built-in default
    /// The list always has at least one entry.
    static var apiBaseURLs: [String] {
        resolveAPIBaseURLs(rawMulti: rawMultiEndpointValue(), rawSingle: rawSingleEndpointValue())
    }

    static func resolveAPIBaseURLs(rawMulti: String?, rawSingle: String?) -> [String] {
        if let multi = parseList(rawMulti), !multi.isEmpty {
            return multi
        }
        if let rawSingle, !rawSingle.isEmpty {
            return [rawSingle]
        }
        return defaultBaseURLs
    }

    /// Backwards-compatible single base URL accessor — returns the first
    /// configured endpoint. New code should use `apiBaseURLs` together with
    /// `CloudEndpointSelector` for latency-based routing and failover.
    static var apiBaseURL: String {
        apiBaseURLs.first ?? (defaultBaseURLs.first ?? "")
    }

    private static func rawMultiEndpointValue() -> String? {
        if let value = ProcessInfo.processInfo.environment["TYPEFLUX_API_URLS"], !value.isEmpty {
            return value
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: "TYPEFLUX_API_URLS") as? String, !value.isEmpty {
            return value
        }
        return nil
    }

    private static func rawSingleEndpointValue() -> String? {
        if let value = ProcessInfo.processInfo.environment["TYPEFLUX_API_URL"], !value.isEmpty {
            return value
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: "TYPEFLUX_API_URL") as? String, !value.isEmpty {
            return value
        }
        return nil
    }

    static func parseList(_ raw: String?) -> [String]? {
        guard let raw, !raw.isEmpty else { return nil }
        let parts = raw
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        // Preserve order while removing duplicates so users can paste a list
        // without worrying about repeated entries.
        var seen = Set<String>()
        var result: [String] = []
        for part in parts {
            if seen.insert(part).inserted {
                result.append(part)
            }
        }
        return result.isEmpty ? nil : result
    }

    /// Google OAuth 2.0 Client ID used only for direct Google Cloud Speech-to-Text access.
    /// This credential is used only for direct Google Cloud Speech-to-Text access.
    static var googleCloudOAuthClientID: String {
        configuredValue(
            environmentKey: "GOOGLE_CLOUD_OAUTH_CLIENT_ID",
            infoPlistKey: "GOOGLE_CLOUD_OAUTH_CLIENT_ID",
            default: defaultGoogleCloudOAuthClientID
        )
    }

    /// Google OAuth 2.0 Client Secret for the dedicated Google Cloud Speech client.
    /// Required only if that client is a Desktop app client.
    static var googleCloudOAuthClientSecret: String {
        configuredValue(
            environmentKey: "GOOGLE_CLOUD_OAUTH_CLIENT_SECRET",
            infoPlistKey: "GOOGLE_CLOUD_OAUTH_CLIENT_SECRET",
            default: ""
        )
    }
}
