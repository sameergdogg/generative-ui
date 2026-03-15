import XCTest
@testable import GenerativeUIDSL

/// Tier 1: Base case tests — single node decoding
final class UINodeDecodingTests: XCTestCase {

    // MARK: - Text Node

    func test_decodeTextNode() throws {
        let node = try decodeNodeFromFixture("simple_text.json")
        guard case .text(let t) = node else {
            return XCTFail("Expected .text, got \(node)")
        }
        XCTAssertEqual(t.content, "Hello World")
        XCTAssertEqual(t.style, "title")
        XCTAssertEqual(t.color, "blue")
        XCTAssertEqual(t.weight, "bold")
    }

    func test_decodeTextNode_minimumFields() throws {
        let node = try decodeNode(from: #"{"type":"text","content":"Hi"}"#)
        guard case .text(let t) = node else {
            return XCTFail("Expected .text")
        }
        XCTAssertEqual(t.content, "Hi")
        XCTAssertNil(t.style)
        XCTAssertNil(t.color)
        XCTAssertNil(t.weight)
        XCTAssertNil(t.maxLines)
    }

    func test_decodeTextNode_withMaxLines() throws {
        let node = try decodeNode(from: #"{"type":"text","content":"Truncated","maxLines":2}"#)
        guard case .text(let t) = node else {
            return XCTFail("Expected .text")
        }
        XCTAssertEqual(t.maxLines, 2)
    }

    // MARK: - Stat Node

    func test_decodeStatNode() throws {
        let node = try decodeNodeFromFixture("simple_stat.json")
        guard case .stat(let s) = node else {
            return XCTFail("Expected .stat, got \(node)")
        }
        XCTAssertEqual(s.label, "Total Spent")
        XCTAssertEqual(s.value, "$491")
        XCTAssertEqual(s.color, "red")
        XCTAssertEqual(s.size, "large")
        XCTAssertEqual(s.icon, "dollarsign.circle")
    }

    func test_decodeStatNode_minimumFields() throws {
        let node = try decodeNode(from: #"{"type":"stat","label":"Count","value":"5"}"#)
        guard case .stat(let s) = node else {
            return XCTFail("Expected .stat")
        }
        XCTAssertEqual(s.label, "Count")
        XCTAssertEqual(s.value, "5")
        XCTAssertNil(s.color)
        XCTAssertNil(s.size)
        XCTAssertNil(s.icon)
    }

    // MARK: - Image Node

    func test_decodeImageNode() throws {
        let json = #"{"type":"image","system_name":"cart.fill","color":"blue","size":"large"}"#
        let node = try decodeNode(from: json)
        guard case .image(let img) = node else {
            return XCTFail("Expected .image")
        }
        XCTAssertEqual(img.systemName, "cart.fill")
        XCTAssertEqual(img.color, "blue")
        XCTAssertEqual(img.size, "large")
    }

    func test_decodeImageNode_minimumFields() throws {
        let node = try decodeNode(from: #"{"type":"image","system_name":"star"}"#)
        guard case .image(let img) = node else {
            return XCTFail("Expected .image")
        }
        XCTAssertEqual(img.systemName, "star")
        XCTAssertNil(img.color)
        XCTAssertNil(img.size)
    }

    // MARK: - Badge Node

    func test_decodeBadgeNode() throws {
        let node = try decodeNode(from: #"{"type":"badge","text":"Food & Dining","color":"orange"}"#)
        guard case .badge(let b) = node else {
            return XCTFail("Expected .badge")
        }
        XCTAssertEqual(b.text, "Food & Dining")
        XCTAssertEqual(b.color, "orange")
    }

    func test_decodeBadgeNode_noColor() throws {
        let node = try decodeNode(from: #"{"type":"badge","text":"Tag"}"#)
        guard case .badge(let b) = node else {
            return XCTFail("Expected .badge")
        }
        XCTAssertEqual(b.text, "Tag")
        XCTAssertNil(b.color)
    }

    // MARK: - Divider & Spacer (stable IDs)

    func test_decodeDivider() throws {
        let node = try decodeNode(from: #"{"type":"divider"}"#)
        guard case .divider = node else {
            return XCTFail("Expected .divider")
        }
    }

    func test_decodeDivider_stableId() throws {
        let node = try decodeNode(from: #"{"type":"divider"}"#)
        // ID should be stable across accesses (not regenerated each time)
        let id1 = node.id
        let id2 = node.id
        XCTAssertEqual(id1, id2, "Divider ID should be stable across accesses")
    }

    func test_decodeSpacer() throws {
        let node = try decodeNode(from: #"{"type":"spacer"}"#)
        guard case .spacer = node else {
            return XCTFail("Expected .spacer")
        }
    }

    func test_decodeSpacer_stableId() throws {
        let node = try decodeNode(from: #"{"type":"spacer"}"#)
        let id1 = node.id
        let id2 = node.id
        XCTAssertEqual(id1, id2, "Spacer ID should be stable across accesses")
    }

    // MARK: - Progress Node

    func test_decodeProgressNode() throws {
        let json = #"{"type":"progress","value":75,"total":100,"label":"Budget Used","color":"green"}"#
        let node = try decodeNode(from: json)
        guard case .progress(let p) = node else {
            return XCTFail("Expected .progress")
        }
        XCTAssertEqual(p.value, 75)
        XCTAssertEqual(p.total, 100)
        XCTAssertEqual(p.label, "Budget Used")
        XCTAssertEqual(p.color, "green")
    }

    func test_decodeProgressNode_defaultTotal() throws {
        let node = try decodeNode(from: #"{"type":"progress","value":0.5}"#)
        guard case .progress(let p) = node else {
            return XCTFail("Expected .progress")
        }
        XCTAssertEqual(p.value, 0.5)
        XCTAssertEqual(p.total, 1.0)
        XCTAssertNil(p.label)
        XCTAssertNil(p.color)
    }

    // MARK: - Table Node

    func test_decodeTableNode() throws {
        let json = #"{"type":"table","title":"Transactions","headers":["Date","Merchant","Amount"],"rows":[["Jan 5","McDonald's","$13"],["Jan 7","Starbucks","$7"]]}"#
        let node = try decodeNode(from: json)
        guard case .table(let t) = node else {
            return XCTFail("Expected .table, got \(nodeTypeString(node))")
        }
        XCTAssertEqual(t.title, "Transactions")
        XCTAssertEqual(t.headers, ["Date", "Merchant", "Amount"])
        XCTAssertEqual(t.rows.count, 2)
        XCTAssertEqual(t.rows[0], ["Jan 5", "McDonald's", "$13"])
    }

    func test_decodeTableNode_minimumFields() throws {
        let node = try decodeNode(from: #"{"type":"table"}"#)
        guard case .table(let t) = node else {
            return XCTFail("Expected .table")
        }
        XCTAssertNil(t.title)
        XCTAssertTrue(t.headers.isEmpty)
        XCTAssertTrue(t.rows.isEmpty)
    }

    // MARK: - Line Chart

    func test_decodeLineChart() throws {
        let json = #"{"type":"chart","variant":"line","title":"Spending Over Time","data":[{"label":"Jan","value":100},{"label":"Feb","value":150},{"label":"Mar","value":80}]}"#
        let node = try decodeNode(from: json)
        guard case .chart(let c) = node else {
            return XCTFail("Expected .chart")
        }
        XCTAssertEqual(c.variant, "line")
        XCTAssertEqual(c.data.count, 3)
    }

    // MARK: - Round-trip Encoding/Decoding

    func test_roundTripText() throws {
        let original = try decodeNode(from: #"{"type":"text","content":"Round trip","style":"headline","color":"red","weight":"bold"}"#)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UINode.self, from: encoded)

        guard case .text(let t) = decoded else {
            return XCTFail("Expected .text after round-trip")
        }
        XCTAssertEqual(t.content, "Round trip")
        XCTAssertEqual(t.style, "headline")
        XCTAssertEqual(t.color, "red")
        XCTAssertEqual(t.weight, "bold")
    }

    func test_roundTripVStack() throws {
        let json = #"{"type":"vstack","spacing":10,"alignment":"leading","children":[{"type":"text","content":"A"},{"type":"text","content":"B"}]}"#
        let original = try decodeNode(from: json)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UINode.self, from: encoded)

        guard case .vstack(let v) = decoded else {
            return XCTFail("Expected .vstack after round-trip")
        }
        XCTAssertEqual(v.children.count, 2)
        XCTAssertEqual(v.spacing, 10)
        XCTAssertEqual(v.alignment, "leading")
    }

    func test_roundTripUIResponse() throws {
        let json = """
        {
          "title": "Test",
          "layout": {"type": "text", "content": "Hello"},
          "spoken_summary": "A test response"
        }
        """
        let original = try decodeUIResponse(from: json)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UIResponse.self, from: encoded)

        XCTAssertEqual(decoded.title, "Test")
        XCTAssertEqual(decoded.spokenSummary, "A test response")
        guard case .text(let t) = decoded.layout else {
            return XCTFail("Expected .text layout")
        }
        XCTAssertEqual(t.content, "Hello")
    }

    func test_roundTripDivider() throws {
        let original = try decodeNode(from: #"{"type":"divider"}"#)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UINode.self, from: encoded)
        guard case .divider = decoded else {
            return XCTFail("Expected .divider after round-trip")
        }
    }

    func test_roundTripTable() throws {
        let json = #"{"type":"table","headers":["A","B"],"rows":[["1","2"]]}"#
        let original = try decodeNode(from: json)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UINode.self, from: encoded)
        guard case .table(let t) = decoded else {
            return XCTFail("Expected .table after round-trip")
        }
        XCTAssertEqual(t.headers, ["A", "B"])
        XCTAssertEqual(t.rows, [["1", "2"]])
    }
}
