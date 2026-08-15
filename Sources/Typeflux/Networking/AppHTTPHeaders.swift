import Foundation

enum AppHTTPHeaders {
    static func apply(to request: inout URLRequest) {
        guard request.value(forHTTPHeaderField: "User-Agent") == nil else { return }
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    }

    private static var userAgent: String {
        let name = bundleValue(for: "CFBundleName") ?? "Typeflux"
        let version = bundleValue(for: "CFBundleShortVersionString") ?? "0.0.0"
        return "\(sanitize(name))/\(sanitize(version))"
    }

    private static func bundleValue(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func sanitize(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
        return value.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
    }
}
