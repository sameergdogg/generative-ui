import XCTest
import SwiftUI
@testable import GenerativeUIDSL

/// Tier 3: Complex edge cases
final class EdgeCaseTests: XCTestCase {

    // MARK: - Deep Nesting

    func test_deeplyNestedTree() throws {
        let node = try decodeNodeFromFixture("deep_nesting.json")
        let allNodes = flattenTree(node)

        // 10 vstacks + 1 text leaf = 11 nodes
        XCTAssertEqual(allNodes.count, 11)

        let textNodes = allNodes.filter { isNodeType($0, "text") }
        XCTAssertEqual(textNodes.count, 1)
        guard case .text(let t) = textNodes.first else {
            return XCTFail("Expected leaf text node")
        }
        XCTAssertEqual(t.content, "Deep leaf")
    }

    // MARK: - Unknown Type Fallback

    func test_unknownTypeFallback() throws {
        let node = try decodeNodeFromFixture("unknown_type.json")
        guard case .text(let t) = node else {
            return XCTFail("Expected unknown type to fall back to .text")
        }
        XCTAssertTrue(t.content.starts(with: "Unknown:"))
        XCTAssertTrue(t.content.contains("fancy_widget"))
    }

    // MARK: - All Optionals Missing

    func test_allOptionalsMissing() throws {
        let response = try decodeResponseFromFixture("all_optionals_missing.json")
        XCTAssertEqual(response.title, "Minimal Response")

        guard case .vstack(let v) = response.layout else {
            return XCTFail("Expected root vstack")
        }
        XCTAssertEqual(v.children.count, 7)

        guard case .text(let t) = v.children[0] else {
            return XCTFail("Expected text")
        }
        XCTAssertNil(t.style)
        XCTAssertNil(t.color)
        XCTAssertNil(t.weight)

        guard case .stat(let s) = v.children[1] else {
            return XCTFail("Expected stat")
        }
        XCTAssertNil(s.color)
        XCTAssertNil(s.size)
        XCTAssertNil(s.icon)

        guard case .image(let img) = v.children[2] else {
            return XCTFail("Expected image")
        }
        XCTAssertNil(img.color)
        XCTAssertNil(img.size)

        guard case .badge(let b) = v.children[3] else {
            return XCTFail("Expected badge")
        }
        XCTAssertNil(b.color)

        guard case .progress(let p) = v.children[4] else {
            return XCTFail("Expected progress")
        }
        XCTAssertEqual(p.total, 1.0)
        XCTAssertNil(p.label)
        XCTAssertNil(p.color)
    }

    // MARK: - Malformed JSON

    func test_malformedJSON_missingType() throws {
        let data = try loadFixture("malformed.json")
        XCTAssertThrowsError(try JSONDecoder().decode(UINode.self, from: data)) { error in
            XCTAssertTrue(error is DecodingError, "Expected DecodingError, got \(error)")
        }
    }

    func test_malformedJSON_invalidStructure() throws {
        let data = #""just a string""#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(UINode.self, from: data))
    }

    func test_malformedJSON_emptyObject() throws {
        let data = "{}".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(UINode.self, from: data))
    }

    // MARK: - Empty Collections

    func test_emptyChildrenArray() throws {
        let node = try decodeNode(from: #"{"type":"vstack","children":[]}"#)
        guard case .vstack(let v) = node else {
            return XCTFail("Expected .vstack")
        }
        XCTAssertEqual(v.children.count, 0)
    }

    func test_chartEmptyData() throws {
        let node = try decodeNode(from: #"{"type":"chart","variant":"bar","data":[]}"#)
        guard case .chart(let c) = node else {
            return XCTFail("Expected .chart")
        }
        XCTAssertEqual(c.data.count, 0)
        XCTAssertNil(c.title)
    }

    func test_listEmptyItems() throws {
        let node = try decodeNode(from: #"{"type":"list","items":[]}"#)
        guard case .list(let l) = node else {
            return XCTFail("Expected .list")
        }
        XCTAssertEqual(l.items.count, 0)
    }

    func test_tableEmptyRows() throws {
        let node = try decodeNode(from: #"{"type":"table","headers":["A","B"],"rows":[]}"#)
        guard case .table(let t) = node else {
            return XCTFail("Expected .table")
        }
        XCTAssertEqual(t.headers.count, 2)
        XCTAssertEqual(t.rows.count, 0)
    }

    // MARK: - Fault-Tolerant Decoding

    func test_faultTolerantChildren_skipsInvalidNodes() throws {
        // A vstack with a mix of valid and invalid children
        let json = """
        {"type":"vstack","children":[
            {"type":"text","content":"Valid 1"},
            {"invalid":"this has no type field"},
            {"type":"text","content":"Valid 2"},
            {"type":"nonexistent_widget","foo":"bar"},
            {"type":"text","content":"Valid 3"}
        ]}
        """
        let node = try decodeNode(from: json)
        guard case .vstack(let v) = node else {
            return XCTFail("Expected .vstack")
        }
        // The invalid node (no "type") should be skipped, but "nonexistent_widget" falls back to text
        // So we expect: Valid 1, Valid 2, Unknown: nonexistent_widget, Valid 3
        // The {"invalid": ...} node is skipped entirely because it has no "type" key
        XCTAssertEqual(v.children.count, 4, "Should have 4 children (1 invalid skipped, 1 unknown→text)")

        // Verify the unknown type fallback
        guard case .text(let unknown) = v.children[2] else {
            return XCTFail("Expected unknown type to become .text")
        }
        XCTAssertTrue(unknown.content.contains("Unknown"))
    }

    func test_faultTolerantList_skipsInvalidItems() throws {
        let json = """
        {"type":"list","items":[
            {"type":"text","content":"Good item"},
            {"broken": true},
            {"type":"text","content":"Another good item"}
        ]}
        """
        let node = try decodeNode(from: json)
        guard case .list(let l) = node else {
            return XCTFail("Expected .list")
        }
        XCTAssertEqual(l.items.count, 2, "Should have 2 items (1 invalid skipped)")
    }

    // MARK: - Diagnostics

    func test_diagnostics_detectsUnknownTypes() {
        let json = """
        {"title":"Test","layout":{"type":"vstack","children":[
            {"type":"text","content":"Valid"},
            {"type":"fancy_widget","data":"something"}
        ]},"spoken_summary":"Test"}
        """
        let data = json.data(using: .utf8)!
        let (response, diagnostics, _) = decodeUIResponseWithDiagnostics(from: data)

        XCTAssertNotNil(response)
        XCTAssertTrue(diagnostics.hasIssues)
        XCTAssertTrue(diagnostics.unknownTypes.contains("fancy_widget"))
    }

    func test_diagnostics_emptyChartWarning() {
        let json = """
        {"title":"Test","layout":{"type":"chart","variant":"bar","data":[]},"spoken_summary":"Test"}
        """
        let data = json.data(using: .utf8)!
        let (response, diagnostics, _) = decodeUIResponseWithDiagnostics(from: data)

        XCTAssertNotNil(response)
        XCTAssertTrue(diagnostics.hasIssues)
        XCTAssertTrue(diagnostics.warnings.contains { $0.contains("no data") })
    }

    func test_diagnostics_emptyTableWarning() {
        let json = """
        {"title":"Test","layout":{"type":"table","headers":[],"rows":[]},"spoken_summary":"Test"}
        """
        let data = json.data(using: .utf8)!
        let (response, diagnostics, _) = decodeUIResponseWithDiagnostics(from: data)

        XCTAssertNotNil(response)
        XCTAssertTrue(diagnostics.hasIssues)
        XCTAssertTrue(diagnostics.warnings.contains { $0.contains("no headers") })
    }

    func test_diagnostics_fullFailure() {
        let data = "not json".data(using: .utf8)!
        let (response, _, rawError) = decodeUIResponseWithDiagnostics(from: data)

        XCTAssertNil(response)
        XCTAssertNotNil(rawError)
    }

    func test_diagnostics_cleanResponse() {
        let json = """
        {"title":"Clean","layout":{"type":"text","content":"Hello"},"spoken_summary":"All good"}
        """
        let data = json.data(using: .utf8)!
        let (response, diagnostics, _) = decodeUIResponseWithDiagnostics(from: data)

        XCTAssertNotNil(response)
        XCTAssertFalse(diagnostics.hasIssues)
    }

    // MARK: - Color Resolution

    func test_colorResolution_knownColors() {
        let knownColors = [
            "red", "blue", "green", "orange", "purple", "pink",
            "yellow", "gray", "grey", "brown", "cyan", "mint",
            "teal", "indigo", "white", "black", "primary", "secondary"
        ]
        for colorName in knownColors {
            let resolved = colorName.resolvedColor
            XCTAssertNotNil(resolved, "Color '\(colorName)' should resolve")
        }
    }

    func test_unknownColorFallback() {
        let resolved = "neonpurple".resolvedColor
        XCTAssertNotNil(resolved)
    }

    func test_colorResolution_caseInsensitive() {
        let resolved = "RED".resolvedColor
        XCTAssertNotNil(resolved)
    }

    // MARK: - Large Tree

    func test_largeTree() throws {
        var items: [String] = []
        for i in 0..<25 {
            items.append(
                "{\"type\":\"hstack\",\"children\":[{\"type\":\"text\",\"content\":\"Item \(i)\"},{\"type\":\"badge\",\"text\":\"#\(i)\"}]}"
            )
        }
        let json = "{\"type\":\"vstack\",\"children\":[{\"type\":\"text\",\"content\":\"Large List\",\"style\":\"title\"},{\"type\":\"list\",\"items\":[\(items.joined(separator: ","))]}]}"
        let node = try decodeNode(from: json)
        let count = nodeCount(node)
        // 1 vstack + 1 text + 1 list + 25*(1 hstack + 1 text + 1 badge) = 78
        XCTAssertEqual(count, 78)
    }

    // MARK: - Real Claude Response

    func test_realClaudeResponseFixture() throws {
        let response = try decodeResponseFromFixture("real_claude_response.json")

        XCTAssertEqual(response.title, "McDonald's Spending Summary")
        XCTAssertFalse(response.spokenSummary.isEmpty)

        let count = nodeCount(response.layout)
        XCTAssertGreaterThan(count, 10, "Real response should have substantial node count")

        let allNodes = flattenTree(response.layout)
        let hasText = allNodes.contains { isNodeType($0, "text") }
        let hasStat = allNodes.contains { isNodeType($0, "stat") }
        let hasCard = allNodes.contains { isNodeType($0, "card") }
        let hasList = allNodes.contains { isNodeType($0, "list") }
        let hasBadge = allNodes.contains { isNodeType($0, "badge") }

        XCTAssertTrue(hasText)
        XCTAssertTrue(hasStat)
        XCTAssertTrue(hasCard)
        XCTAssertTrue(hasList)
        XCTAssertTrue(hasBadge)
    }

    // MARK: - Node Count Utility

    func test_nodeCountSingleNode() {
        let node = UINode.text(TextNode(content: "Solo", style: nil, color: nil, weight: nil, maxLines: nil))
        XCTAssertEqual(nodeCount(node), 1)
    }

    func test_nodeCountDividerSpacer() {
        XCTAssertEqual(nodeCount(.divider(id: "d")), 1)
        XCTAssertEqual(nodeCount(.spacer(id: "s")), 1)
    }
}
