@testable import Typeflux
import XCTest

final class WindowContextReducerTests: XCTestCase {
    func testReduceReturnsAllUniqueContentBelowLimit() {
        let result = WindowContextReducer.reduce(
            "Title\nFirst paragraph\nFirst paragraph\nLast paragraph",
            query: "anything",
            characterLimit: 1000
        )

        XCTAssertEqual(result, "Title\nFirst paragraph\nLast paragraph")
    }

    func testReduceKeepsRelevantMiddleContentWhenWindowIsLarge() {
        let unrelated = (0 ..< 40).map { "Unrelated navigation item \($0)" }
        let relevant = "The deployment uses Cloudflare Durable Objects for coordination."
        let trailing = (0 ..< 20).map { "Recent chat message \($0)" }
        let text = (unrelated + [relevant] + trailing).joined(separator: "\n")

        let result = WindowContextReducer.reduce(
            text,
            query: "Please explain the Durable Objects coordination",
            characterLimit: 500
        )

        XCTAssertTrue(result.contains(relevant))
        XCTAssertLessThanOrEqual(result.count, 500)
        XCTAssertTrue(result.contains("unrelated window content omitted"))
    }

    func testReduceUsesChineseTermsForRelevance() {
        let text = (0 ..< 30).map { "普通菜单项目 \($0)" }.joined(separator: "\n")
            + "\n这里讨论语音识别上下文裁剪的准确率\n"
            + (0 ..< 20).map { "其他消息 \($0)" }.joined(separator: "\n")

        let result = WindowContextReducer.reduce(
            text,
            query: "帮我总结一下上下文裁剪的准确率",
            characterLimit: 320
        )

        XCTAssertTrue(result.contains("语音识别上下文裁剪的准确率"))
        XCTAssertLessThanOrEqual(result.count, 320)
    }

    func testReduceKeepsRecentWindowTailWithoutMatches() {
        let text = (0 ..< 60).map { "Window line \($0)" }.joined(separator: "\n")

        let result = WindowContextReducer.reduce(
            text,
            query: "nonmatching query",
            characterLimit: 220
        )

        XCTAssertTrue(result.contains("Window line 59"))
        XCTAssertLessThanOrEqual(result.count, 220)
    }
}
