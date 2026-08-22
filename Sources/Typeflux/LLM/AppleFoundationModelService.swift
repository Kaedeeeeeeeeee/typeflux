import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleFoundationModelAvailability: Equatable, Sendable {
    case available
    case unsupportedSystemVersion
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady

    var isAvailable: Bool {
        self == .available
    }

    var localizedMessage: String {
        switch self {
        case .available:
            L("settings.models.appleFoundationModel.available")
        case .unsupportedSystemVersion:
            L("settings.models.appleFoundationModel.unsupportedSystemVersion")
        case .deviceNotEligible:
            L("settings.models.appleFoundationModel.deviceNotEligible")
        case .appleIntelligenceNotEnabled:
            L("settings.models.appleFoundationModel.appleIntelligenceNotEnabled")
        case .modelNotReady:
            L("settings.models.appleFoundationModel.modelNotReady")
        }
    }
}

enum AppleFoundationModelError: LocalizedError, Equatable {
    case unavailable(AppleFoundationModelAvailability)

    var errorDescription: String? {
        switch self {
        case let .unavailable(availability):
            availability.localizedMessage
        }
    }
}

protocol AppleFoundationModelRuntime: AnyObject {
    var availability: AppleFoundationModelAvailability { get }

    func streamResponse(
        instructions: String,
        prompt: String,
        temperature: Double
    ) -> AsyncThrowingStream<String, Error>

    func respond(
        instructions: String,
        prompt: String,
        temperature: Double
    ) async throws -> String

    func respond(
        instructions: String,
        prompt: String,
        schema: LLMJSONSchema,
        temperature: Double
    ) async throws -> String
}

final class AppleFoundationModelService: LLMService {
    private let settingsStore: SettingsStore
    private let runtime: AppleFoundationModelRuntime

    init(
        settingsStore: SettingsStore,
        runtime: AppleFoundationModelRuntime = SystemAppleFoundationModelRuntime()
    ) {
        self.settingsStore = settingsStore
        self.runtime = runtime
    }

    var availability: AppleFoundationModelAvailability {
        runtime.availability
    }

    func streamRewrite(request: LLMRewriteRequest) -> AsyncThrowingStream<String, Error> {
        do {
            try ensureAvailable()
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

        let prompts = PromptCatalog.rewritePrompts(for: request)
        var effectiveSystemPrompt = PromptCatalog.appendLanguageResolutionPolicy(to: prompts.system)
        let effectiveUserPrompt = PromptCatalog.appendUserEnvironmentContext(
            to: prompts.user,
            appLanguage: settingsStore.appLanguage
        )
        if let appContext = request.appSystemContext {
            let extra = PromptCatalog.appSpecificSystemContext(appContext)
            if !extra.isEmpty {
                effectiveSystemPrompt = PromptCatalog.appendAdditionalSystemContext(
                    extra,
                    to: effectiveSystemPrompt
                )
            }
        }

        NetworkDebugLogger.logMessage(
            PromptCatalog.rewritePromptDebugDescription(
                system: effectiveSystemPrompt,
                user: effectiveUserPrompt
            )
        )
        return runtime.streamResponse(
            instructions: effectiveSystemPrompt,
            prompt: effectiveUserPrompt,
            temperature: 0.4
        )
    }

    func complete(systemPrompt: String, userPrompt: String) async throws -> String {
        try ensureAvailable()
        return try await runtime.respond(
            instructions: PromptCatalog.appendLanguageResolutionPolicy(to: systemPrompt),
            prompt: PromptCatalog.appendUserEnvironmentContext(
                to: userPrompt,
                appLanguage: settingsStore.appLanguage
            ),
            temperature: 0.1
        )
    }

    func completeJSON(
        systemPrompt: String,
        userPrompt: String,
        schema: LLMJSONSchema
    ) async throws -> String {
        try ensureAvailable()
        return try await runtime.respond(
            instructions: PromptCatalog.appendLanguageResolutionPolicy(to: systemPrompt),
            prompt: PromptCatalog.appendUserEnvironmentContext(
                to: userPrompt,
                appLanguage: settingsStore.appLanguage
            ),
            schema: schema,
            temperature: 0.1
        )
    }

    private func ensureAvailable() throws {
        let currentAvailability = runtime.availability
        guard currentAvailability.isAvailable else {
            throw AppleFoundationModelError.unavailable(currentAvailability)
        }
    }
}

final class SystemAppleFoundationModelRuntime: AppleFoundationModelRuntime {
    var availability: AppleFoundationModelAvailability {
#if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .deviceNotEligible
            case .unavailable(.appleIntelligenceNotEnabled):
                return .appleIntelligenceNotEnabled
            case .unavailable(.modelNotReady):
                return .modelNotReady
            case .unavailable:
                return .modelNotReady
            }
        }
#endif
        return .unsupportedSystemVersion
    }

    func streamResponse(
        instructions: String,
        prompt: String,
        temperature: Double
    ) -> AsyncThrowingStream<String, Error> {
#if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return streamSystemResponse(
                instructions: instructions,
                prompt: prompt,
                temperature: temperature
            )
        }
#endif
        return unavailableStream()
    }

    func respond(
        instructions: String,
        prompt: String,
        temperature: Double
    ) async throws -> String {
#if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            try ensureAvailable()
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: prompt,
                options: GenerationOptions(temperature: temperature)
            )
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
#endif
        throw AppleFoundationModelError.unavailable(.unsupportedSystemVersion)
    }

    func respond(
        instructions: String,
        prompt: String,
        schema: LLMJSONSchema,
        temperature: Double
    ) async throws -> String {
#if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            try ensureAvailable()
            let session = LanguageModelSession(instructions: instructions)
            let nativeSchema: GenerationSchema
            do {
                nativeSchema = try AppleFoundationModelSchemaBuilder.makeSchema(from: schema)
            } catch {
                return try await respondWithJSONPromptFallback(
                    session: session,
                    prompt: prompt,
                    schema: schema,
                    temperature: temperature
                )
            }
            let response = try await session.respond(
                to: prompt,
                schema: nativeSchema,
                options: GenerationOptions(temperature: temperature)
            )
            return response.content.jsonString
        }
#endif
        throw AppleFoundationModelError.unavailable(.unsupportedSystemVersion)
    }

    private func unavailableStream() -> AsyncThrowingStream<String, Error> {
        let error = AppleFoundationModelError.unavailable(availability)
        return AsyncThrowingStream { $0.finish(throwing: error) }
    }

    private func ensureAvailable() throws {
        let currentAvailability = availability
        guard currentAvailability.isAvailable else {
            throw AppleFoundationModelError.unavailable(currentAvailability)
        }
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
private extension SystemAppleFoundationModelRuntime {
    func streamSystemResponse(
        instructions: String,
        prompt: String,
        temperature: Double
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try ensureAvailable()
                    let session = LanguageModelSession(instructions: instructions)
                    let stream = session.streamResponse(
                        to: prompt,
                        options: GenerationOptions(temperature: temperature)
                    )
                    var previousSnapshot = ""
                    for try await snapshot in stream {
                        try Task.checkCancellation()
                        let currentSnapshot = snapshot.content
                        let delta: String
                        if currentSnapshot.hasPrefix(previousSnapshot) {
                            delta = String(currentSnapshot.dropFirst(previousSnapshot.count))
                        } else {
                            delta = currentSnapshot
                        }
                        previousSnapshot = currentSnapshot
                        if !delta.isEmpty {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func respondWithJSONPromptFallback(
        session: LanguageModelSession,
        prompt: String,
        schema: LLMJSONSchema,
        temperature: Double
    ) async throws -> String {
        let schemaData = try JSONSerialization.data(
            withJSONObject: schema.jsonObject,
            options: [.sortedKeys]
        )
        let schemaText = String(data: schemaData, encoding: .utf8) ?? "{}"
        let fallbackPrompt = """
        \(prompt)

        Return only valid JSON matching this JSON Schema. Do not include markdown fences.
        \(schemaText)
        """
        let response = try await session.respond(
            to: fallbackPrompt,
            options: GenerationOptions(temperature: temperature)
        )
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#endif
