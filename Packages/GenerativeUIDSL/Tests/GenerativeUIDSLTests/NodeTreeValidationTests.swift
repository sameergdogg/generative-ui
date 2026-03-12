import XCTest
@testable import GenerativeUIDSL

/// Tier 2: Medium cases — nested layouts and tree validation
final class NodeTreeValidationTests: XCTestCase {

    // MARK: - VStack

    func test_vstackWithChildren() throws {
        let node = try decodeNodeFromFixture("nested_vstack.json")
        guard case .vstack(let v) = node else {
            return XCTFail("Expected .vstack")
        }
        XCTAssertEqual(v.children.count, 3)
        XCTAssertEqual(v.spacing, 12)
        XCTAssertEqual(v.alignment, "leading")

        for child in v.children {
            XCTAssertTrue(isNodeType(child, "text"), "Expected child to be text")
        }
    }

    // MARK: - HStack with Stats

    func test_hstackWithStats() throws {
        let json = """
        {"type":"hstack","spacing":12,"children":[
            {"type":"stat","label":"Total","value":"$100","icon":"dollarsign.circle"},
            {"type":"stat","label":"Count","value":"5","icon":"list.bullet"}
        ]}
        """
        let node = try decodeNode(from: json)
        guard case .hstack(let h) = node else {
            return XCTFail("Expected .hstack")
        }
        XCTAssertEqual(h.children.count, 2)
        for child in h.children {
            guard case .stat = child else {
                return XCTFail("Expected .stat child")
            }
        }
    }

    // MARK: - Card Wrapping

    func test_cardWrappingVStack() throws {
        let node = try decodeNodeFromFixture("card_with_children.json")
        guard case .card(let card) = node else {
            return XCTFail("Expected .card")
        }
        XCTAssertEqual(card.color, "blue")
        XCTAssertEqual(card.padding, 16)
        XCTAssertEqual(card.cornerRadius, 12)

        guard case .vstack(let v) = card.child else {
            return XCTFail("Expected card child to be .vstack")
        }
        XCTAssertEqual(v.children.count, 3)

        guard case .text(let title) = v.children[0] else {
            return XCTFail("Expected first child to be .text")
        }
        XCTAssertEqual(title.content, "Card Title")

        guard case .badge(let badge) = v.children[1] else {
            return XCTFail("Expected second child to be .badge")
        }
        XCTAssertEqual(badge.text, "Food & Dining")
    }

    // MARK: - List

    func test_listWithItems() throws {
        let json = """
        {"type":"list","items":[
            {"type":"hstack","children":[{"type":"text","content":"Row 1"}]},
            {"type":"hstack","children":[{"type":"text","content":"Row 2"}]},
            {"type":"hstack","children":[{"type":"text","content":"Row 3"}]},
            {"type":"hstack","children":[{"type":"text","content":"Row 4"}]}
        ]}
        """
        let node = try decodeNode(from: json)
        guard case .list(let list) = node else {
            return XCTFail("Expected .list")
        }
        XCTAssertEqual(list.items.count, 4)
        for item in list.items {
            XCTAssertTrue(isNodeType(item, "hstack"))
        }
    }

    // MARK: - Mixed Children

    func test_vstackMixedChildren() throws {
        let json = """
        {"type":"vstack","children":[
            {"type":"text","content":"Title"},
            {"type":"divider"},
            {"type":"stat","label":"X","value":"1"},
            {"type":"spacer"},
            {"type":"badge","text":"Tag"}
        ]}
        """
        let node = try decodeNode(from: json)
        guard case .vstack(let v) = node else {
            return XCTFail("Expected .vstack")
        }
        XCTAssertEqual(v.children.count, 5)
        XCTAssertTrue(isNodeType(v.children[0], "text"))
        XCTAssertTrue(isNodeType(v.children[1], "divider"))
        XCTAssertTrue(isNodeType(v.children[2], "stat"))
        XCTAssertTrue(isNodeType(v.children[3], "spacer"))
        XCTAssertTrue(isNodeType(v.children[4], "badge"))
    }

    // MARK: - Charts

    func test_chartBar() throws {
        let node = try decodeNodeFromFixture("chart_bar.json")
        guard case .chart(let chart) = node else {
            return XCTFail("Expected .chart")
        }
        XCTAssertEqual(chart.variant, "bar")
        XCTAssertEqual(chart.title, "Spending by Category")
        XCTAssertEqual(chart.data.count, 3)
        XCTAssertEqual(chart.data[0].label, "Food")
        XCTAssertEqual(chart.data[0].value, 120.5)
        XCTAssertEqual(chart.data[0].color, "orange")
    }

    func test_chartPie() throws {
        let node = try decodeNodeFromFixture("chart_pie.json")
        guard case .chart(let chart) = node else {
            return XCTFail("Expected .chart")
        }
        XCTAssertEqual(chart.variant, "pie")
        XCTAssertEqual(chart.data.count, 4)
    }

    func test_chartLine() throws {
        let json = #"{"type":"chart","variant":"line","title":"Trend","data":[{"label":"W1","value":10},{"label":"W2","value":20},{"label":"W3","value":15}]}"#
        let node = try decodeNode(from: json)
        guard case .chart(let chart) = node else {
            return XCTFail("Expected .chart")
        }
        XCTAssertEqual(chart.variant, "line")
        XCTAssertEqual(chart.data.count, 3)
    }

    // MARK: - Table

    func test_tableWithHeadersAndRows() throws {
        let json = """
        {"type":"table","title":"Expenses","headers":["Date","Amount","Merchant"],"rows":[
            ["Jan 5","$13","McDonald's"],
            ["Jan 7","$7","Starbucks"],
            ["Jan 10","$45","Shell Gas"]
        ]}
        """
        let node = try decodeNode(from: json)
        guard case .table(let table) = node else {
            return XCTFail("Expected .table")
        }
        XCTAssertEqual(table.title, "Expenses")
        XCTAssertEqual(table.headers.count, 3)
        XCTAssertEqual(table.rows.count, 3)
        XCTAssertEqual(table.rows[0][2], "McDonald's")
    }

    // MARK: - Full UIResponse

    func test_fullUIResponse() throws {
        let response = try decodeResponseFromFixture("real_claude_response.json")
        XCTAssertEqual(response.title, "McDonald's Spending Summary")
        XCTAssertFalse(response.spokenSummary.isEmpty)

        guard case .vstack(let root) = response.layout else {
            return XCTFail("Expected root to be .vstack")
        }
        XCTAssertTrue(root.children.count >= 3, "Expected at least 3 children in root")

        let allNodes = flattenTree(response.layout)
        let types = Set(allNodes.map { nodeTypeString($0) })
        XCTAssertTrue(types.contains("vstack"))
        XCTAssertTrue(types.contains("hstack"))
        XCTAssertTrue(types.contains("text"))
        XCTAssertTrue(types.contains("stat"))
    }

    // MARK: - ZStack

    func test_zstackWithChildren() throws {
        let json = """
        {"type":"zstack","alignment":"center","children":[
            {"type":"text","content":"Background"},
            {"type":"text","content":"Foreground"}
        ]}
        """
        let node = try decodeNode(from: json)
        guard case .zstack(let z) = node else {
            return XCTFail("Expected .zstack")
        }
        XCTAssertEqual(z.children.count, 2)
        XCTAssertEqual(z.alignment, "center")
    }
}
