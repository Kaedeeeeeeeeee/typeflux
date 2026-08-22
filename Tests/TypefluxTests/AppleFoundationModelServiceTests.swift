@testable import Typeflux
import XCTest

private final class StubAppleFoundationModelRuntime: AppleFoundationModelRuntime {
    var availability: AppleFoundationModelAvailability = .available
    var streamedChunks: [String] = []
    var response = "response"
    var structuredResponse = "{}"
    var lastInstructions: String?
    var lastPrompt: String?
    var lastSchemaName: String?

    func streamResponse(
        instructions: String,
        prompt: String,
        temperature _: Double
    ) -> AsyncThrowingStream<String, Error> {
        lastInstructions = instructions
        lastPrompt = prompt
        let chunks = streamedChunks
        return AsyncThrowingStream { continuation in
            chunks.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }

    func respond(
        instructions: String,
        prompt: String,
        temperature _: Double
    ) async throws -> String {
        lastInstructions = instructions
        lastPrompt = prompt
        return response
    }

    func respond(
        instructions: String,
        prompt: String,
        schema: LLMJSONSchema,
        temperature _: Double
    ) async throws -> String {
        lastInstructions = instructions
        lastPrompt = prompt
        lastSchemaName = schema.name
        return structuredResponse
    }
}

final class AppleFoundationModelServiceTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settings: SettingsStore!
    private var runtime: StubAppleFoundationModelRuntime!
    private var service: AppleFoundationModelService!

    override func setUp() {
        super.setUp()
        suiteName = "AppleFoundationModelServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settings = SettingsStore(defaults: defaults)
        runtime = StubAppleFoundationModelRuntime()
        service = AppleFoundationModelService(settingsStore: settings, runtime: runtime)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        service = nil
        runtime = nil
        settings = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testCompleteRejectsUnavailableSystemModel() async {
        runtime.availability = .modelNotReady

        do {
            _ = try await service.complete(systemPrompt: "System", userPrompt: "User")
            XCTFail("Expected an unavailable model error")
        } catch let error as AppleFoundationModelError {
            XCTAssertEqual(error, .unavailable(.modelNotReady))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCompleteUsesRuntimeAndReturnsResponse() async throws {
        runtime.response = "local result"

        let result = try await service.complete(systemPrompt: "System", userPrompt: "User")

        XCTAssertEqual(result, "local result")
        XCTAssertTrue(runtime.lastInstructions?.contains("System") == true)
        XCTAssertTrue(runtime.lastPrompt?.contains("User") == true)
    }

    func testStreamRewriteForwardsRuntimeChunks() async throws {
        runtime.streamedChunks = ["first", " second"]
        let request = LLMRewriteRequest(
            mode: .rewriteTranscript,
            sourceText: "raw text",
            spokenInstruction: nil,
            personaPrompt: nil
        )

        var received: [String] = []
        for try await chunk in service.streamRewrite(request: request) {
            received.append(chunk)
        }

        XCTAssertEqual(received, ["first", " second"])
        XCTAssertTrue(runtime.lastPrompt?.contains("raw text") == true)
    }

    func testCompleteJSONUsesNativeRuntimeSchemaPath() async throws {
        runtime.structuredResponse = #"{"answer":"ok"}"#
        let schema = LLMJSONSchema(name: "answer", schema: [:])

        let result = try await service.completeJSON(
            systemPrompt: "System",
            userPrompt: "User",
            schema: schema
        )

        XCTAssertEqual(result, #"{"answer":"ok"}"#)
        XCTAssertEqual(runtime.lastSchemaName, "answer")
    }

#if canImport(FoundationModels)
    @available(macOS 26.0, *)
    func testNativeSchemaBuilderAcceptsObjectProperties() throws {
        let schema = LLMJSONSchema(
            name: "answer",
            schema: [
                "type": .string("object"),
                "properties": .object([
                    "answer": .object(["type": .string("string")]),
                    "confidence": .object(["type": .string("number")])
                ]),
                "required": .array([.string("answer")])
            ]
        )

        XCTAssertNoThrow(try AppleFoundationModelSchemaBuilder.makeSchema(from: schema))
    }
#endif
}
