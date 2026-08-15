import Foundation

struct TranscriptionSnapshot {
    let text: String
    let isFinal: Bool
}

protocol Transcriber {
    func transcribe(audioFile: AudioFile) async throws -> String
    func transcribeStream(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String
}

protocol RecordingPrewarmingTranscriber: Transcriber {
    func prepareForRecording() async
    func cancelPreparedRecording() async
}

protocol RealtimeTranscriptionSessionFactory: Transcriber {
    func makeRealtimeTranscriptionSession(
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> any RealtimeTranscriptionSession
}

extension Transcriber {
    func transcribeStream(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        let text = try await transcribe(audioFile: audioFile)
        await onUpdate(TranscriptionSnapshot(text: text, isFinal: true))
        return text
    }
}

final class STTRouter {
    let settingsStore: SettingsStore
    let whisper: Transcriber
    let freeSTT: Transcriber
    let appleSpeech: Transcriber
    let localModel: Transcriber
    let multimodal: Transcriber
    let aliCloud: Transcriber
    let doubaoRealtime: Transcriber
    let googleCloud: Transcriber
    let groq: Transcriber
    let soniox: Transcriber
    let deepgram: Transcriber
    let autoModelDownloadService: AutoModelDownloadService?

    init(
        settingsStore: SettingsStore,
        whisper: Transcriber,
        freeSTT: Transcriber,
        appleSpeech: Transcriber,
        localModel: Transcriber,
        multimodal: Transcriber,
        aliCloud: Transcriber,
        doubaoRealtime: Transcriber,
        googleCloud: Transcriber,
        groq: Transcriber,
        soniox: Transcriber,
        deepgram: Transcriber,
        autoModelDownloadService: AutoModelDownloadService? = nil
    ) {
        self.settingsStore = settingsStore
        self.whisper = whisper
        self.freeSTT = freeSTT
        self.appleSpeech = appleSpeech
        self.localModel = localModel
        self.multimodal = multimodal
        self.aliCloud = aliCloud
        self.doubaoRealtime = doubaoRealtime
        self.googleCloud = googleCloud
        self.groq = groq
        self.soniox = soniox
        self.deepgram = deepgram
        self.autoModelDownloadService = autoModelDownloadService
    }

    func transcribe(audioFile: AudioFile) async throws -> String {
        try await transcribeStream(audioFile: audioFile) { _ in }
    }
}
