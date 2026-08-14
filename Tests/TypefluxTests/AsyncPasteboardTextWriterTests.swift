@testable import Typeflux
import XCTest

final class AsyncPasteboardTextWriterTests: XCTestCase {
    @MainActor
    func testWriteOperationRunsOffMainThreadAndCompletesOnMainActor() async {
        let completionExpectation = expectation(description: "write completed")
        let writer = AsyncPasteboardTextWriter { _ in
            !Thread.isMainThread
        }

        writer.write("transcript") { didWrite in
            XCTAssertTrue(didWrite)
            XCTAssertTrue(Thread.isMainThread)
            completionExpectation.fulfill()
        }

        await fulfillment(of: [completionExpectation], timeout: 1)
    }

    @MainActor
    func testWriteOperationPropagatesFailure() async {
        let completionExpectation = expectation(description: "write failed")
        let writer = AsyncPasteboardTextWriter { _ in false }

        writer.write("transcript") { didWrite in
            XCTAssertFalse(didWrite)
            completionExpectation.fulfill()
        }

        await fulfillment(of: [completionExpectation], timeout: 1)
    }
}
