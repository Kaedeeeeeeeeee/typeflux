import Foundation

enum LLMConnectionTestResolver {
    static func resolve(
        provider: LLMRemoteProvider,
        baseURL: String,
        model: String,
        apiKey: String
    ) async throws -> ResolvedLLMConnection {
        return try LLMConnectionResolver.resolve(
            provider: provider,
            baseURL: baseURL,
            model: model,
            apiKey: apiKey
        )
    }
}
