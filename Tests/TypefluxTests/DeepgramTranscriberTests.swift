@testable import Typeflux
import XCTest

final class DeepgramTranscriberTests: XCTestCase {
    func testAutomaticLanguageRequestUsesDetectionAndNovaDefaults() throws {
        let audioData = Data([0x52, 0x49, 0x46, 0x46])
        let request = try DeepgramTranscriber.makeRequest(
            audioData: audioData,
            model: "",
            apiKey: "  dg-secret  ",
            language: .automatic,
            keyterms: ["Typeflux", " ", "Deepgram"]
        )

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Token dg-secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "audio/wav")
        XCTAssertEqual(request.httpBody, audioData)

        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "api.deepgram.com")
        XCTAssertEqual(components.path, "/v1/listen")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "model" })?.value, "nova-3")
        XCTAssertNil(components.queryItems?.first(where: { $0.name == "language" }))
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "detect_language" })?.value,
            "true"
        )
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "smart_format" })?.value, "true")
        XCTAssertEqual(
            components.queryItems?.filter { $0.name == "keyterm" }.compactMap(\.value),
            ["Typeflux", "Deepgram"]
        )
    }

    func testExplicitLanguageRequestsUseSelectedLanguageCodeWithoutDetection() throws {
        for language in DeepgramLanguage.allCases where language != .automatic {
            let request = try DeepgramTranscriber.makeRequest(
                audioData: Data([0x52, 0x49, 0x46, 0x46]),
                model: DeepgramASRDefaults.model,
                apiKey: "dg-secret",
                language: language,
                keyterms: []
            )

            let components = try XCTUnwrap(
                URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
            )
            XCTAssertEqual(
                components.queryItems?.first(where: { $0.name == "language" })?.value,
                language.languageCode
            )
            XCTAssertNil(components.queryItems?.first(where: { $0.name == "detect_language" }))
        }
    }

    func testRequestRequiresAPIKey() {
        XCTAssertThrowsError(
            try DeepgramTranscriber.makeRequest(
                audioData: Data(),
                model: DeepgramASRDefaults.model,
                apiKey: " ",
                language: .automatic,
                keyterms: []
            )
        ) { error in
            XCTAssertEqual((error as NSError).domain, "DeepgramTranscriber")
            XCTAssertTrue(error.localizedDescription.contains("API key"))
        }
    }

    func testTranscriptParsesFirstChannelAlternative() throws {
        let data = Data(
            """
            {
              "results": {
                "channels": [
                  {
                    "alternatives": [
                      {"transcript": "  你好 Typeflux  "}
                    ]
                  }
                ]
              }
            }
            """.utf8
        )

        let transcript = try DeepgramTranscriber.transcript(
            from: data,
            response: response(statusCode: 200)
        )

        XCTAssertEqual(transcript, "你好 Typeflux")
    }

    func testTranscriptSurfacesDeepgramErrorMessage() {
        let data = Data(
            """
            {"err_code":"INVALID_AUTH","err_msg":"Invalid credentials."}
            """.utf8
        )

        XCTAssertThrowsError(
            try DeepgramTranscriber.transcript(
                from: data,
                response: response(statusCode: 401)
            )
        ) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, 401)
            XCTAssertTrue(nsError.localizedDescription.contains("Invalid credentials"))
        }
    }

    func testTranscriptRejectsMalformedSuccessResponse() {
        XCTAssertThrowsError(
            try DeepgramTranscriber.transcript(
                from: Data("{}".utf8),
                response: response(statusCode: 200)
            )
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("invalid transcription response"))
        }
    }

    private func response(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: DeepgramASRDefaults.endpoint)!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}
