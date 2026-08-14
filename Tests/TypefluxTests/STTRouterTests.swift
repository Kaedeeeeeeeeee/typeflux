@testable import Typeflux
import XCTest

private final class RouterMockTranscriber: Transcriber {
    var result = "transcribed"
    var error: Error?
    private(set) var callCount = 0

    func transcribe(audioFile _: AudioFile) async throws -> String {
        callCount += 1
        if let error {
            throw error
        }
        return result
    }

    func transcribeStream(
        audioFile _: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        callCount += 1
        if let error {
            throw error
        }
        await onUpdate(TranscriptionSnapshot(text: result, isFinal: true))
        return result
    }
}

private final class RouterPrewarmingTranscriber: RecordingPrewarmingTranscriber {
    private(set) var prepareCallCount = 0

    func transcribe(audioFile _: AudioFile) async throws -> String {
        "transcribed"
    }

    func prepareForRecording() async {
        prepareCallCount += 1
    }

    func cancelPreparedRecording() async {}
}

final class STTRouterTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settings: SettingsStore!
    private var transcribers: [STTProvider: RouterMockTranscriber]!

    override func setUp() {
        super.setUp()
        suiteName = "STTRouterTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settings = SettingsStore(defaults: defaults)
        settings.groqSTTAPIKey = "test-key"
        transcribers = Dictionary(uniqueKeysWithValues: STTProvider.allCases.map {
            ($0, RouterMockTranscriber())
        })
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        transcribers = nil
        settings = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRoutesEveryProviderToItsConfiguredTranscriber() async throws {
        for provider in STTProvider.allCases {
            settings.sttProvider = provider
            transcribers[provider]?.result = provider.rawValue

            let result = try await makeRouter().transcribe(audioFile: dummyAudioFile())

            XCTAssertEqual(result, provider.rawValue)
            XCTAssertEqual(transcribers[provider]?.callCount, 1)
        }
    }

    func testFallsBackToAppleSpeechWhenLocalModelFailsAndFallbackEnabled() async throws {
        settings.sttProvider = .localModel
        settings.useAppleSpeechFallback = true
        transcribers[.localModel]?.error = NSError(domain: "test", code: 1)
        transcribers[.appleSpeech]?.result = "apple fallback"

        let result = try await makeRouter().transcribe(audioFile: dummyAudioFile())

        XCTAssertEqual(result, "apple fallback")
        XCTAssertEqual(transcribers[.appleSpeech]?.callCount, 1)
    }

    func testThrowsWhenLocalModelFailsAndFallbackDisabled() async {
        settings.sttProvider = .localModel
        settings.useAppleSpeechFallback = false
        transcribers[.localModel]?.error = NSError(domain: "test", code: 1)

        do {
            _ = try await makeRouter().transcribe(audioFile: dummyAudioFile())
            XCTFail("Expected local transcription error")
        } catch {
            XCTAssertEqual((error as NSError).domain, "test")
        }
    }

    func testPrepareForRecordingDelegatesToRealtimeProvider() async {
        settings.sttProvider = .doubaoRealtime
        let prewarming = RouterPrewarmingTranscriber()

        await makeRouter(doubaoRealtime: prewarming).prepareForRecording()

        XCTAssertEqual(prewarming.prepareCallCount, 1)
    }

    private func makeRouter(doubaoRealtime: Transcriber? = nil) -> STTRouter {
        STTRouter(
            settingsStore: settings,
            whisper: transcribers[.whisperAPI]!,
            freeSTT: transcribers[.freeModel]!,
            appleSpeech: transcribers[.appleSpeech]!,
            localModel: transcribers[.localModel]!,
            multimodal: transcribers[.multimodalLLM]!,
            aliCloud: transcribers[.aliCloud]!,
            doubaoRealtime: doubaoRealtime ?? transcribers[.doubaoRealtime]!,
            googleCloud: transcribers[.googleCloud]!,
            groq: transcribers[.groq]!,
            soniox: transcribers[.soniox]!,
            deepgram: transcribers[.deepgram]!
        )
    }

    private func dummyAudioFile() -> AudioFile {
        AudioFile(fileURL: URL(fileURLWithPath: "/dev/null"), duration: 1)
    }
}
