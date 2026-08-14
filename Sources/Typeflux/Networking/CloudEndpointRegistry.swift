import Foundation
import os

/// Process-wide registry holding the shared `CloudEndpointSelector` used by
/// app-owned network caller (currently updater and direct feedback).
///
/// Existing call sites are static (`AutoUpdater.shared`, `FeedbackAPIService`), so a
/// global registry keeps the rewrite contained while still allowing tests to
/// override the selector with a stub.
enum CloudEndpointRegistry {
    private static let lock = NSLock()
    private static var override: CloudEndpointSelector?

    private nonisolated(unsafe) static var cached: CloudEndpointSelector?

    static var shared: CloudEndpointSelector {
        lock.lock()
        defer { lock.unlock() }
        if let override { return override }
        if let cached { return cached }
        let urls = AppServerConfiguration.apiBaseURLs.compactMap(URL.init(string:))
        let resolved = urls.isEmpty ? [URL(string: "https://typeflux.app")!] : urls
        let selector = CloudEndpointSelector(
            baseURLs: resolved,
            prober: HTTPCloudEndpointProber()
        )
        cached = selector
        return selector
    }

    /// Replaces the shared selector — for use in tests only.
    static func setOverride(_ selector: CloudEndpointSelector?) {
        lock.lock()
        defer { lock.unlock() }
        override = selector
    }
}
