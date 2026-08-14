extension STTRouter {
    func prepareForRecording() async {
        switch settingsStore.sttProvider {
        case .doubaoRealtime:
            await (doubaoRealtime as? RecordingPrewarmingTranscriber)?.prepareForRecording()
        case .localModel:
            await (localModel as? RecordingPrewarmingTranscriber)?.prepareForRecording()
        default:
            break
        }
    }

    func cancelPreparedRecording() async {
        switch settingsStore.sttProvider {
        case .doubaoRealtime:
            await (doubaoRealtime as? RecordingPrewarmingTranscriber)?.cancelPreparedRecording()
        case .localModel:
            await (localModel as? RecordingPrewarmingTranscriber)?.cancelPreparedRecording()
        default:
            break
        }
    }

    func makeRealtimeTranscriptionSession(
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async -> (any RealtimeTranscriptionSession)? {
        switch settingsStore.sttProvider {
        case .aliCloud:
            await makeRealtimeTranscriptionSession(
                provider: aliCloud,
                onUpdate: onUpdate,
                failureContext: "Alibaba Cloud realtime session setup failed"
            )
        case .doubaoRealtime:
            await makeRealtimeTranscriptionSession(
                provider: doubaoRealtime,
                onUpdate: onUpdate,
                failureContext: "Doubao realtime session setup failed"
            )
        case .googleCloud:
            await makeRealtimeTranscriptionSession(
                provider: googleCloud,
                onUpdate: onUpdate,
                failureContext: "Google Cloud realtime session setup failed"
            )
        case .soniox:
            await makeRealtimeTranscriptionSession(
                provider: soniox,
                onUpdate: onUpdate,
                failureContext: "Soniox realtime session setup failed"
            )
        default:
            nil
        }
    }

    private func makeRealtimeTranscriptionSession(
        provider: Transcriber,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void,
        failureContext: String
    ) async -> (any RealtimeTranscriptionSession)? {
        guard let factory = provider as? RealtimeTranscriptionSessionFactory else {
            return nil
        }
        do {
            let diagnostics = RealtimeTranscriptionDiagnostics()
            let observedUpdate: @Sendable (TranscriptionSnapshot) async -> Void = { snapshot in
                diagnostics.markResult(isFinal: snapshot.isFinal)
                await onUpdate(snapshot)
            }
            let session = try await factory.makeRealtimeTranscriptionSession(
                onUpdate: observedUpdate
            )
            return ObservedRealtimeTranscriptionSession(
                upstream: session,
                diagnostics: diagnostics
            )
        } catch {
            NetworkDebugLogger.logError(context: failureContext, error: error)
            return nil
        }
    }
}
