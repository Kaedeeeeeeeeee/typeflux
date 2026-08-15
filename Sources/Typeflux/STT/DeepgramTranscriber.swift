import Foundation

final class DeepgramTranscriber: Transcriber {
    private let settingsStore: SettingsStore
    private let urlSession: URLSession

    init(settingsStore: SettingsStore, urlSession: URLSession = .shared) {
        self.settingsStore = settingsStore
        self.urlSession = urlSession
    }

    static func testConnection(
        apiKey: String,
        model: String = DeepgramASRDefaults.model,
        language: DeepgramLanguage = .automatic,
        urlSession: URLSession = .shared
    ) async throws -> String {
        let request = try makeRequest(
            audioData: RemoteSTTTestAudio.wavSilence(),
            model: resolvedModel(model),
            apiKey: apiKey,
            language: language,
            keyterms: []
        )
        let (data, response) = try await urlSession.data(for: request)
        return try transcript(from: data, response: response)
    }

    func transcribe(audioFile: AudioFile) async throws -> String {
        try await transcribeStream(audioFile: audioFile) { _ in }
    }

    func transcribeStream(
        audioFile: AudioFile,
        onUpdate: @escaping @Sendable (TranscriptionSnapshot) async -> Void
    ) async throws -> String {
        let apiKey = settingsStore.deepgramAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = Self.resolvedModel(settingsStore.deepgramModel)
        let language = settingsStore.deepgramLanguage
        let uploadURL = try AudioFileTranscoder.wavFileURL(for: audioFile)
        let audioData = try Data(contentsOf: uploadURL)
        let request = try Self.makeRequest(
            audioData: audioData,
            model: model,
            apiKey: apiKey,
            language: language,
            keyterms: Array(VocabularyStore.activeTerms().prefix(100))
        )

        NetworkDebugLogger.logRequest(
            request,
            bodyDescription: """
            {
              "provider": "Deepgram",
              "model": "\(model)",
              "language": "\(language.rawValue)",
              "format": "audio/wav",
              "sizeBytes": \(audioData.count)
            }
            """
        )

        let (data, response) = try await urlSession.data(for: request)
        NetworkDebugLogger.logResponse(response, data: data)
        let text = try Self.transcript(from: data, response: response)
        await onUpdate(TranscriptionSnapshot(text: text, isFinal: true))
        return text
    }

    static func makeRequest(
        audioData: Data,
        model: String,
        apiKey: String,
        language: DeepgramLanguage,
        keyterms: [String]
    ) throws -> URLRequest {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw NSError(
                domain: "DeepgramTranscriber",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Deepgram API key is not configured."]
            )
        }

        guard var components = URLComponents(string: DeepgramASRDefaults.endpoint) else {
            throw NSError(
                domain: "DeepgramTranscriber",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Deepgram transcription endpoint."]
            )
        }

        components.queryItems = [
            URLQueryItem(name: "model", value: resolvedModel(model)),
            URLQueryItem(name: "smart_format", value: "true")
        ]
        if let languageCode = language.languageCode {
            components.queryItems?.append(URLQueryItem(name: "language", value: languageCode))
        } else {
            components.queryItems?.append(URLQueryItem(name: "detect_language", value: "true"))
        }
        components.queryItems?.append(contentsOf: keyterms.compactMap { term in
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : URLQueryItem(name: "keyterm", value: trimmed)
        })

        guard let url = components.url else {
            throw NSError(
                domain: "DeepgramTranscriber",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unable to construct the Deepgram transcription URL."]
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Token \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        return request
    }

    static func transcript(from data: Data, response: URLResponse) throws -> String {
        guard let http = response as? HTTPURLResponse else {
            throw NSError(
                domain: "DeepgramTranscriber",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response type from Deepgram."]
            )
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            throw NSError(
                domain: "DeepgramTranscriber",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: errorMessage(from: data, statusCode: http.statusCode)]
            )
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let results = json["results"] as? [String: Any],
            let channels = results["channels"] as? [[String: Any]],
            let channel = channels.first,
            let alternatives = channel["alternatives"] as? [[String: Any]],
            let alternative = alternatives.first,
            let transcript = alternative["transcript"] as? String
        else {
            throw NSError(
                domain: "DeepgramTranscriber",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Deepgram returned an invalid transcription response."]
            )
        }

        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resolvedModel(_ model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? DeepgramASRDefaults.model : trimmed
    }

    private static func errorMessage(from data: Data, statusCode: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = (json["err_msg"] as? String) ?? (json["message"] as? String) {
            return "Deepgram HTTP \(statusCode): \(message)"
        }

        let body = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return body.isEmpty
            ? "Deepgram request failed with HTTP \(statusCode)."
            : "Deepgram HTTP \(statusCode): \(body)"
    }
}
