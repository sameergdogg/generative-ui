import XCTest
@testable import TransactionAI

final class ClaudeServiceTests: XCTestCase {

    // MARK: - extractJSON

    func test_extractJSON_plainJSON() {
        let input = #"{"title":"Test","layout":{"type":"text","content":"Hi"},"spoken_summary":"Hello"}"#
        let result = ClaudeService.extractJSON(from: input)
        XCTAssertEqual(result, input)
    }

    func test_extractJSON_markdownWrapped() {
        let input = """
        ```json
        {"title":"Test","layout":{"type":"text","content":"Hi"},"spoken_summary":"Hello"}
        ```
        """
        let result = ClaudeService.extractJSON(from: input)
        XCTAssertTrue(result.hasPrefix("{"))
        XCTAssertTrue(result.hasSuffix("}"))
        XCTAssertFalse(result.contains("```"))
    }

    func test_extractJSON_markdownWrappedNoLanguage() {
        let input = """
        ```
        {"key":"value"}
        ```
        """
        let result = ClaudeService.extractJSON(from: input)
        XCTAssertTrue(result.hasPrefix("{"))
        XCTAssertFalse(result.contains("```"))
    }

    func test_extractJSON_withWhitespace() {
        let input = "  \n  {\"key\":\"value\"}  \n  "
        let result = ClaudeService.extractJSON(from: input)
        XCTAssertEqual(result, #"{"key":"value"}"#)
    }
}
