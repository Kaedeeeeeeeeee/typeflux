import Foundation

extension AXTextInjector {
    private static let browserBundleIdentifiers: Set<String> = [
        "app.zen-browser.zen",
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.brave.Browser",
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.canary",
        "com.google.Chrome.dev",
        "com.kagi.kagimacOS",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Canary",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "company.thebrowser.Browser",
        "org.chromium.Chromium",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition"
    ]

    private static let terminalBundleIdentifiers: Set<String> = [
        "co.zeit.hyper",
        "com.apple.Terminal",
        "com.github.wez.wezterm",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "com.tabby",
        "dev.warp.Warp-Preview",
        "dev.warp.Warp-Stable",
        "io.alacritty",
        "net.kovidgoyal.kitty",
        "org.alacritty"
    ]

    static func isBrowserApplication(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return browserBundleIdentifiers.contains(bundleIdentifier)
    }

    static func shouldResolveFocusedWindowDescendants(bundleIdentifier: String?) -> Bool {
        // A browser window contains several editable controls. When AX does not
        // expose the page control directly, walking the window commonly resolves
        // to the address bar even though DOM focus is still in the page.
        !isBrowserApplication(bundleIdentifier: bundleIdentifier)
    }

    static func allowsUnicodeEventInput(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return true }

        // Terminals generally ignore Unicode payloads attached to synthetic key
        // events. Browsers may route them to their default chrome control instead
        // of the DOM field. Both reliably handle the existing Cmd+V fallback.
        return !terminalBundleIdentifiers.contains(bundleIdentifier)
            && !isBrowserApplication(bundleIdentifier: bundleIdentifier)
    }
}
