@testable import Typeflux
import XCTest

final class ServerErrorMessageTests: XCTestCase {
    func testKnownCodeUsesLocalizedMessageInsteadOfServerMessage() {
        withEnglishLocalization {
            let message = ServerErrorMessage.userMessage(
                code: "VALIDATION_ERROR",
                message: "raw backend message",
                fallback: "fallback"
            )

            XCTAssertEqual(message, "The request was invalid. Please check the input and try again.")
        }
    }

    func testCodeNormalizationAcceptsHyphenatedLowercaseValues() {
        XCTAssertEqual(
            ServerErrorMessage.localizationKey(for: "rate-limited"),
            "cloud.error.rateLimited"
        )
    }

    func testUnknownCodeUsesTrimmedServerMessageThenFallback() {
        XCTAssertEqual(
            ServerErrorMessage.userMessage(
                code: "CUSTOM_ERROR",
                message: "  Custom failure  ",
                fallback: "fallback"
            ),
            "Custom failure"
        )
        XCTAssertEqual(
            ServerErrorMessage.userMessage(code: "CUSTOM_ERROR", message: "  ", fallback: "fallback"),
            "fallback"
        )
    }

    private func withEnglishLocalization(_ body: () -> Void) {
        let originalLanguage = AppLocalization.shared.language
        AppLocalization.shared.setLanguage(.english)
        defer { AppLocalization.shared.setLanguage(originalLanguage) }
        body()
    }
}
