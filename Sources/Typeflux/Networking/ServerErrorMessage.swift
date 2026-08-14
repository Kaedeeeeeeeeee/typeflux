import Foundation

enum ServerErrorMessage {
    static func userMessage(code: String, message: String?, fallback: String) -> String {
        if let key = localizationKey(for: code) {
            return L(key)
        }

        let trimmedMessage = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedMessage.isEmpty ? fallback : trimmedMessage
    }

    static func localizationKey(for code: String) -> String? {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            .uppercased()

        switch normalizedCode {
        case "VALIDATION_ERROR", "BAD_REQUEST", "INVALID_REQUEST":
            return "cloud.error.validation"
        case "RATE_LIMITED", "RATE_LIMIT_EXCEEDED", "TOO_MANY_REQUESTS":
            return "cloud.error.rateLimited"
        case "SERVER_ERROR", "INTERNAL", "INTERNAL_SERVER_ERROR":
            return "cloud.error.server"
        default:
            if normalizedCode.hasSuffix("_RATE_LIMITED")
                || normalizedCode.hasSuffix("_RATE_LIMIT_EXCEEDED") {
                return "cloud.error.rateLimited"
            }
            return nil
        }
    }
}
