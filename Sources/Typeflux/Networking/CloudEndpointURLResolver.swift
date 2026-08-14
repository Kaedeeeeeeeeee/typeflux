import Foundation

/// Joins an app service base URL with an API path, accommodating base URLs
/// that may or may not include a trailing slash.
enum CloudEndpointURLResolver {
    static func resolve(baseURL: URL, path: String) -> URL {
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) ?? URLComponents()
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if basePath.isEmpty {
            components.path = "/" + trimmedPath
        } else {
            components.path = "/" + basePath + "/" + trimmedPath
        }
        if let url = components.url { return url }
        return URL(string: baseURL.absoluteString + path) ?? baseURL
    }
}
