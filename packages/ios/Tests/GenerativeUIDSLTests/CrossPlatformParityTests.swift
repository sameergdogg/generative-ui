import XCTest
@testable import GenerativeUIDSL

final class CrossPlatformParityTests: XCTestCase {

    private func decodeResponse(fixture name: String) throws -> UIResponse {
        let data = try loadFixture(name)
        return try JSONDecoder().decode(UIResponse.self, from: data)
    }

    private func decodeNodeFixture(_ name: String) throws -> UINode {
        let data = try loadFixture(name)
        return try JSONDecoder().decode(UINode.self, from: data)
    }

    private var snapshotDir: URL {
        let packageDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return packageDir.appendingPathComponent("spec/test-snapshots")
    }

    private func assertSnapshotMatches(_ name: String, snapshot: String, file: StaticString = #file, line: UInt = #line) {
        let goldenURL = snapshotDir.appendingPathComponent("\(name).txt")

        try? FileManager.default.createDirectory(at: snapshotDir, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: goldenURL.path) {
            do {
                let golden = try String(contentsOf: goldenURL, encoding: .utf8)
                XCTAssertEqual(golden, snapshot,
                    "Snapshot mismatch for \(name). Delete golden file to regenerate: \(goldenURL.path)",
                    file: file, line: line)
            } catch {
                XCTFail("Failed to read golden snapshot: \(error)", file: file, line: line)
            }
        } else {
            do {
                try snapshot.write(to: goldenURL, atomically: true, encoding: .utf8)
                print("  [CREATED] Golden snapshot: \(name).txt")
            } catch {
                XCTFail("Failed to write golden snapshot: \(error)", file: file, line: line)
            }
        }
    }

    // MARK: - Snapshot Parity Tests

    func testSnapshot_realClaudeResponse() throws {
        let response = try decodeResponse(fixture: "real_claude_response.json")
        let snapshot = RenderSnapshot.generate(response.layout)
        assertSnapshotMatches("real_claude_response", snapshot: snapshot)
    }

    func testSnapshot_crossPlatformSmoke() throws {
        let response = try decodeResponse(fixture: "cross_platform_smoke.json")
        let snapshot = RenderSnapshot.generate(response.layout)
        assertSnapshotMatches("cross_platform_smoke", snapshot: snapshot)
    }

    func testSnapshot_financialDashboard() throws {
        let response = try decodeResponse(fixture: "financial_dashboard.json")
        let snapshot = RenderSnapshot.generate(response.layout)
        assertSnapshotMatches("financial_dashboard", snapshot: snapshot)
    }

    func testSnapshot_groceryBreakdown() throws {
        let response = try decodeResponse(fixture: "grocery_breakdown.json")
        let snapshot = RenderSnapshot.generate(response.layout)
        assertSnapshotMatches("grocery_breakdown", snapshot: snapshot)
    }

    func testSnapshot_budgetStatus() throws {
        let response = try decodeResponse(fixture: "budget_status.json")
        let snapshot = RenderSnapshot.generate(response.layout)
        assertSnapshotMatches("budget_status", snapshot: snapshot)
    }

    func testSnapshot_subscriptionTracker() throws {
        let response = try decodeResponse(fixture: "subscription_tracker.json")
        let snapshot = RenderSnapshot.generate(response.layout)
        assertSnapshotMatches("subscription_tracker", snapshot: snapshot)
    }

    func testSnapshot_weeklySpendingTrend() throws {
        let response = try decodeResponse(fixture: "weekly_spending_trend.json")
        let snapshot = RenderSnapshot.generate(response.layout)
        assertSnapshotMatches("weekly_spending_trend", snapshot: snapshot)
    }

    func testSnapshot_nestedVstack() throws {
        let node = try decodeNodeFixture("nested_vstack.json")
        let snapshot = RenderSnapshot.generate(node)
        assertSnapshotMatches("nested_vstack", snapshot: snapshot)
    }

    func testSnapshot_cardWithChildren() throws {
        let node = try decodeNodeFixture("card_with_children.json")
        let snapshot = RenderSnapshot.generate(node)
        assertSnapshotMatches("card_with_children", snapshot: snapshot)
    }

    func testSnapshot_chartBar() throws {
        let node = try decodeNodeFixture("chart_bar.json")
        let snapshot = RenderSnapshot.generate(node)
        assertSnapshotMatches("chart_bar", snapshot: snapshot)
    }

    func testSnapshot_chartPie() throws {
        let node = try decodeNodeFixture("chart_pie.json")
        let snapshot = RenderSnapshot.generate(node)
        assertSnapshotMatches("chart_pie", snapshot: snapshot)
    }

    func testSnapshot_allOptionalsMissing() throws {
        let response = try decodeResponse(fixture: "all_optionals_missing.json")
        let snapshot = RenderSnapshot.generate(response.layout)
        assertSnapshotMatches("all_optionals_missing", snapshot: snapshot)
    }

    // MARK: - Layout Behavior Validation

    func testHStackChildrenGetEqualWeight() throws {
        let json = """
        {"type":"hstack","spacing":10,"children":[
            {"type":"stat","label":"A","value":"1","size":"large"},
            {"type":"stat","label":"B","value":"2","size":"large"},
            {"type":"stat","label":"C","value":"3","size":"large"}
        ]}
        """
        let node = try decodeNode(from: json)
        let snapshot = RenderSnapshot.generate(node)

        XCTAssertTrue(snapshot.contains("fillsWidth=true"), "HStack should fill width")
        let weightedCount = snapshot.components(separatedBy: "weighted=true").count - 1
        XCTAssertEqual(weightedCount, 3, "All 3 stats in HStack should be weighted")
    }

    func testStandaloneStatFillsWidth() throws {
        let json = """
        {"type":"stat","label":"Total","value":"$100","size":"large"}
        """
        let node = try decodeNode(from: json)
        let snapshot = RenderSnapshot.generate(node)

        XCTAssertTrue(snapshot.contains("fillsWidth=true"), "Standalone stat should fill width")
        XCTAssertFalse(snapshot.contains("weighted=true"), "Standalone stat should not be weighted")
    }

    func testCardFillsWidth() throws {
        let json = """
        {"type":"card","child":{"type":"text","content":"Hello"}}
        """
        let node = try decodeNode(from: json)
        let snapshot = RenderSnapshot.generate(node)

        XCTAssertTrue(snapshot.contains("fillsWidth=true"), "Card should fill width")
    }

    func testSpacerInHStackIsWeighted() throws {
        let json = """
        {"type":"hstack","children":[
            {"type":"text","content":"Left"},
            {"type":"spacer"},
            {"type":"text","content":"Right"}
        ]}
        """
        let node = try decodeNode(from: json)
        let snapshot = RenderSnapshot.generate(node)

        XCTAssertTrue(snapshot.contains("Spacer(weighted=true)"), "Spacer in HStack should be weighted")
    }

    func testFinancialDashboardHStackStats() throws {
        let response = try decodeResponse(fixture: "financial_dashboard.json")
        let snapshot = RenderSnapshot.generate(response.layout)
        let lines = snapshot.components(separatedBy: "\n")

        guard let hstackIdx = lines.firstIndex(where: { $0.contains("HStack") && $0.contains("spacing=10") }) else {
            XCTFail("Should find HStack with spacing=10")
            return
        }

        let statLines = lines[(hstackIdx + 1)..<min(hstackIdx + 4, lines.count)]
        let statCount = statLines.filter { $0.contains("Stat(") }.count
        let weightedCount = statLines.filter { $0.contains("weighted=true") }.count

        XCTAssertEqual(statCount, 3, "HStack should have 3 stat children")
        XCTAssertEqual(weightedCount, 3, "All stats in HStack should be weighted")
    }

    // MARK: - Node Count Parity

    func testNodeCountsMatchExpected() throws {
        let expected: [(String, Int)] = [
            ("deep_nesting.json", 11),
            ("nested_vstack.json", 4),
            ("card_with_children.json", 5),
        ]

        for (fixture, expectedCount) in expected {
            let node = try decodeNodeFixture(fixture)
            XCTAssertEqual(nodeCount(node), expectedCount, "Node count mismatch for \(fixture)")
        }
    }
}
