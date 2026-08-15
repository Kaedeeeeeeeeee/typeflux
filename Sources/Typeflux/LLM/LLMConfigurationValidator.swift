import Foundation

enum LLMConfigurationStatus: Equatable {
    case ready
    case notConfigured(reason: LLMConfigurationFailureReason)
}

enum LLMConfigurationError: LocalizedError, Equatable {
    case notConfigured(reason: LLMConfigurationFailureReason)

    var errorDescription: String? {
        switch self {
        case let .notConfigured(reason):
            reason.localizedMessage
        }
    }
}

enum LLMConfigurationFailureReason: Equatable {
    case missingAPIKey
    case incompleteConfig(details: String)

    var localizedMessage: String {
        switch self {
        case .missingAPIKey:
            L("workflow.llmNotConfigured.missingAPIKey")
        case .incompleteConfig:
            L("workflow.llmNotConfigured.incomplete")
        }
    }
}

struct LLMConfigurationValidator {
    let settingsStore: SettingsStore

    func validate() -> LLMConfigurationStatus {
        switch settingsStore.llmProvider {
        case .ollama:
            let baseURL = settingsStore.ollamaBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let model = settingsStore.ollamaModel.trimmingCharacters(in: .whitespacesAndNewlines)
            if baseURL.isEmpty || model.isEmpty {
                return .notConfigured(
                    reason: .incompleteConfig(details: "Ollama base URL or model not configured")
                )
            }
            return .ready

        case .openAICompatible:
            switch settingsStore.llmRemoteProvider {
            case .freeModel:
                let model = settingsStore.llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
                return model.isEmpty
                    ? .notConfigured(
                        reason: .incompleteConfig(details: "Free model not selected")
                    )
                    : .ready

            case .custom:
                let baseURL = settingsStore.llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                let model = settingsStore.llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
                if baseURL.isEmpty || model.isEmpty {
                    return .notConfigured(
                        reason: .incompleteConfig(details: "Custom LLM base URL or model not configured")
                    )
                }
                return .ready

            default:
                let baseURL = settingsStore.llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                let model = settingsStore.llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
                let apiKey = settingsStore.llmAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                if baseURL.isEmpty || model.isEmpty || apiKey.isEmpty {
                    return .notConfigured(reason: .missingAPIKey)
                }
                return .ready
            }
        }
    }
}
