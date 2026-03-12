import XCTest
@testable import TransactionAI
import GenerativeUIDSL

/// Integration tests that call the real Claude API.
/// Skipped unless CLAUDE_API_KEY environment variable is set.
final class ClaudeIntegrationTests: XCTestCase {

    private var service: ClaudeService!
    private var csvContent: String!

    override func setUp() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] != nil,
            "CLAUDE_API_KEY not set — skipping integration tests"
        )

        let apiKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"]!
        service = ClaudeService(apiKey: apiKey)

        csvContent = """
        date,merchant,category,amount,payment_method,notes
        2026-01-05,McDonald's,Food & Dining,12.50,Credit Card,Lunch
        2026-01-07,Starbucks,Food & Dining,6.75,Debit Card,Morning coffee
        2026-01-10,Shell Gas,Transportation,45.00,Credit Card,Gas fill-up
        2026-01-12,McDonald's,Food & Dining,8.99,Credit Card,Drive-through
        2026-01-14,Amazon,Shopping,67.99,Credit Card,Household supplies
        2026-01-15,Netflix,Entertainment,15.99,Credit Card,Monthly subscription
        2026-01-18,Trader Joe's,Groceries,52.30,Debit Card,Weekly groceries
        2026-01-20,Uber,Transportation,18.50,Credit Card,Ride to airport
        2026-01-22,Target,Shopping,43.21,Debit Card,Clothing
        2026-01-25,Whole Foods,Groceries,78.45,Credit Card,Organic groceries
        """
    }

    // MARK: - Simple Query

    func test_simpleQuery() async throws {
        let response = try await service.sendQuery(
            prompt: "What's my total spending?",
            csvContent: csvContent
        )

        XCTAssertFalse(response.title.isEmpty)
        XCTAssertFalse(response.spokenSummary.isEmpty)

        let count = nodeCount(response.layout)
        XCTAssertGreaterThan(count, 1, "Response should have more than 1 node")
    }

    // MARK: - List Query

    func test_listQuery() async throws {
        let response = try await service.sendQuery(
            prompt: "Show me my McDonald's transactions",
            csvContent: csvContent
        )

        let allNodes = flattenTree(response.layout)
        let textNodes = allNodes.compactMap { node -> String? in
            guard case .text(let t) = node else { return nil }
            return t.content
        }

        let mentionsMcDonalds = textNodes.contains { $0.contains("McDonald") }
        XCTAssertTrue(mentionsMcDonalds, "Response should reference McDonald's")
    }

    // MARK: - Chart Query

    func test_chartQuery() async throws {
        let response = try await service.sendQuery(
            prompt: "Compare my spending by category as a bar chart",
            csvContent: csvContent
        )

        let allNodes = flattenTree(response.layout)
        let chartNodes = allNodes.filter { isNodeType($0, "chart") }
        XCTAssertGreaterThan(chartNodes.count, 0, "Response should contain at least one chart")
    }

    // MARK: - Complex Query

    func test_complexQuery() async throws {
        let response = try await service.sendQuery(
            prompt: "Give me a financial dashboard with spending stats and a chart",
            csvContent: csvContent
        )

        let count = nodeCount(response.layout)
        XCTAssertGreaterThan(count, 5, "Complex response should have 5+ nodes")

        let allNodes = flattenTree(response.layout)
        let typeSet = Set(allNodes.map { nodeTypeString($0) })
        XCTAssertGreaterThan(typeSet.count, 2, "Complex response should use multiple node types")
    }

    // MARK: - Table Query

    func test_tableQuery() async throws {
        let response = try await service.sendQuery(
            prompt: "Show me a table of all my transactions with date, merchant, and amount columns",
            csvContent: csvContent
        )

        let allNodes = flattenTree(response.layout)
        let tableNodes = allNodes.filter { isNodeType($0, "table") }
        // Table may be rendered as a table node or as a list — both are acceptable
        let listNodes = allNodes.filter { isNodeType($0, "list") }
        XCTAssertTrue(tableNodes.count > 0 || listNodes.count > 0,
                      "Response should contain a table or list node")
    }

    // MARK: - Diagnostics Integration

    func test_diagnosticsOnValidResponse() async throws {
        let response = try await service.sendQuery(
            prompt: "What's my total spending?",
            csvContent: csvContent
        )

        // Run diagnostics on the response
        let encoded = try JSONEncoder().encode(response)
        let (decoded, diagnostics, _) = decodeUIResponseWithDiagnostics(from: encoded)

        XCTAssertNotNil(decoded)
        // A re-encoded valid response should have no issues
        XCTAssertFalse(diagnostics.hasIssues, "Re-encoded response should have no diagnostics issues")
    }
}

// MARK: - Helpers (duplicated from package tests since they're in a different target)

private func nodeCount(_ node: UINode) -> Int {
    switch node {
    case .vstack(let n): return 1 + n.children.map(nodeCount).reduce(0, +)
    case .hstack(let n): return 1 + n.children.map(nodeCount).reduce(0, +)
    case .zstack(let n): return 1 + n.children.map(nodeCount).reduce(0, +)
    case .card(let n): return 1 + nodeCount(n.child)
    case .list(let n): return 1 + n.items.map(nodeCount).reduce(0, +)
    case .text, .stat, .image, .badge, .progress, .divider, .spacer, .chart, .table: return 1
    }
}

private func flattenTree(_ node: UINode) -> [UINode] {
    var result = [node]
    switch node {
    case .vstack(let n): for child in n.children { result += flattenTree(child) }
    case .hstack(let n): for child in n.children { result += flattenTree(child) }
    case .zstack(let n): for child in n.children { result += flattenTree(child) }
    case .card(let n): result += flattenTree(n.child)
    case .list(let n): for item in n.items { result += flattenTree(item) }
    case .text, .stat, .image, .badge, .progress, .divider, .spacer, .chart, .table: break
    }
    return result
}

private func isNodeType(_ node: UINode, _ type: String) -> Bool {
    nodeTypeString(node) == type
}

private func nodeTypeString(_ node: UINode) -> String {
    switch node {
    case .vstack: return "vstack"
    case .hstack: return "hstack"
    case .zstack: return "zstack"
    case .text: return "text"
    case .stat: return "stat"
    case .chart: return "chart"
    case .list: return "list"
    case .table: return "table"
    case .divider: return "divider"
    case .spacer: return "spacer"
    case .image: return "image"
    case .badge: return "badge"
    case .card: return "card"
    case .progress: return "progress"
    }
}
