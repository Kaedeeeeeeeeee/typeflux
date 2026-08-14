import Foundation

extension STTRouter {
    func handleLocalModelFailure(
        _ error: Error,
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        NetworkDebugLogger.logError(context: "Local STT failed", error: error)
        if let localResult = await transcribeWithAutoModelIfReady(audioFile: audioFile, onUpdate: onUpdate) {
            NetworkDebugLogger.logMessage("Auto local model succeeded after local STT failure")
            return localResult
        }
        if let appleResult = try await transcribeWithAppleSpeechFallbackIfEnabled(
            message: "Falling back to Apple Speech after local STT failure",
            audioFile: audioFile,
            onUpdate: onUpdate
        ) {
            return appleResult
        }
        throw error
    }

    func transcribeWithAutoModelIfReady(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async -> String? {
        guard settingsStore.localOptimizationEnabled,
              let transcriber = autoModelDownloadService?.makeTranscriberIfReady()
        else {
            return nil
        }
        return try? await transcriber.transcribeStream(audioFile: audioFile, onUpdate: onUpdate)
    }

    func transcribeWithAppleSpeechFallbackIfEnabled(
        message: String,
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String? {
        guard settingsStore.useAppleSpeechFallback else {
            return nil
        }
        NetworkDebugLogger.logMessage(message)
        return try await appleSpeech.transcribeStream(audioFile: audioFile, onUpdate: onUpdate)
    }
}
