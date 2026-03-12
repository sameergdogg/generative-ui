import XCTest
@testable import TransactionAI

final class TransactionQueryServiceTests: XCTestCase {

    private var service: TransactionQueryService!

    override func setUp() {
        let csv = """
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
        2026-02-01,McDonald's,Food & Dining,10.25,Credit Card,Breakfast
        """
        let transactions = CSVParser.parse(csv: csv)
        service = TransactionQueryService(transactions: transactions)
    }

    // MARK: - filter_transactions

    func test_filterByMerchant() throws {
        let result = try execute("filter_transactions", ["merchant": "McDonald"])
        let txns = result["transactions"] as! [[String: Any]]
        let total = result["total_matching"] as! Int

        XCTAssertEqual(total, 3)
        XCTAssertEqual(txns.count, 3)
        for txn in txns {
            XCTAssertTrue((txn["merchant"] as! String).contains("McDonald"))
        }
    }

    func test_filterByCategory() throws {
        let result = try execute("filter_transactions", ["category": "Transportation"])
        let total = result["total_matching"] as! Int
        XCTAssertEqual(total, 2)
    }

    func test_filterByDateRange() throws {
        let result = try execute("filter_transactions", [
            "date_from": "2026-01-10",
            "date_to": "2026-01-20"
        ])
        // 01-10 Shell, 01-12 McDonald's, 01-14 Amazon, 01-15 Netflix, 01-18 Trader Joe's, 01-20 Uber = 6
        let total = result["total_matching"] as! Int
        XCTAssertEqual(total, 6)
    }

    func test_filterByAmountRange() throws {
        let result = try execute("filter_transactions", [
            "min_amount": 40,
            "max_amount": 70
        ])
        let txns = result["transactions"] as! [[String: Any]]
        for txn in txns {
            let amount = txn["amount"] as! Double
            XCTAssertGreaterThanOrEqual(amount, 40)
            XCTAssertLessThanOrEqual(amount, 70)
        }
    }

    func test_filterCombined() throws {
        let result = try execute("filter_transactions", [
            "category": "Food & Dining",
            "merchant": "McDonald"
        ])
        let total = result["total_matching"] as! Int
        XCTAssertEqual(total, 3)
    }

    func test_filterLimit() throws {
        let result = try execute("filter_transactions", ["limit": 3])
        let txns = result["transactions"] as! [[String: Any]]
        XCTAssertEqual(txns.count, 3)
    }

    func test_filterSortByAmount() throws {
        let result = try execute("filter_transactions", [
            "sort_by": "amount",
            "sort_order": "asc"
        ])
        let txns = result["transactions"] as! [[String: Any]]
        let amounts = txns.map { $0["amount"] as! Double }
        XCTAssertEqual(amounts, amounts.sorted())
    }

    func test_filterEmptyResults() throws {
        let result = try execute("filter_transactions", ["merchant": "NonExistentMerchant"])
        let total = result["total_matching"] as! Int
        XCTAssertEqual(total, 0)
    }

    // MARK: - aggregate_spending

    func test_aggregateUngrouped() throws {
        let json = try service.executeTool(name: "aggregate_spending", input: [:])
        let result = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [String: Any]
        let total = result["total"] as! Double
        XCTAssertGreaterThan(total, 0)
        XCTAssertEqual(result["count"] as! Int, 11)
    }

    func test_aggregateByCategory() throws {
        let json = try service.executeTool(name: "aggregate_spending", input: ["group_by": "category"])
        let groups = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [[String: Any]]
        let categoryNames = Set(groups.map { $0["group"] as! String })
        XCTAssertTrue(categoryNames.contains("Food & Dining"))
        XCTAssertTrue(categoryNames.contains("Transportation"))
        XCTAssertTrue(categoryNames.contains("Shopping"))
    }

    func test_aggregateByMerchant() throws {
        let json = try service.executeTool(name: "aggregate_spending", input: ["group_by": "merchant"])
        let groups = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [[String: Any]]
        let mcDonalds = groups.first { $0["group"] as? String == "McDonald's" }
        XCTAssertNotNil(mcDonalds)
        XCTAssertEqual(mcDonalds?["count"] as? Int, 3)
    }

    func test_aggregateByMonth() throws {
        let json = try service.executeTool(name: "aggregate_spending", input: ["group_by": "month"])
        let groups = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [[String: Any]]
        let months = Set(groups.map { $0["group"] as! String })
        XCTAssertTrue(months.contains("2026-01"))
        XCTAssertTrue(months.contains("2026-02"))
    }

    func test_aggregateWithFilter() throws {
        let json = try service.executeTool(name: "aggregate_spending", input: [
            "category": "Food & Dining",
            "group_by": "merchant"
        ])
        let groups = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [[String: Any]]
        let merchants = Set(groups.map { $0["group"] as! String })
        // Only food merchants
        XCTAssertTrue(merchants.contains("McDonald's"))
        XCTAssertTrue(merchants.contains("Starbucks"))
        XCTAssertFalse(merchants.contains("Amazon"))
    }

    func test_aggregateMetrics() throws {
        let json = try service.executeTool(name: "aggregate_spending", input: [
            "merchant": "McDonald"
        ])
        let result = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [String: Any]
        XCTAssertEqual(result["count"] as? Int, 3)
        let total = result["total"] as! Double
        XCTAssertEqual(total, 31.74, accuracy: 0.01)
        XCTAssertEqual(result["min"] as! Double, 8.99, accuracy: 0.01)
        XCTAssertEqual(result["max"] as! Double, 12.50, accuracy: 0.01)
    }

    // MARK: - list_unique_values

    func test_listCategories() throws {
        let json = try service.executeTool(name: "list_unique_values", input: ["field": "category"])
        let values = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [[String: Any]]
        let names = values.map { $0["value"] as! String }
        XCTAssertTrue(names.contains("Food & Dining"))
        XCTAssertTrue(names.contains("Groceries"))
        // Sorted by count desc — Food & Dining has the most (4)
        XCTAssertEqual(names.first, "Food & Dining")
    }

    func test_listMerchants() throws {
        let json = try service.executeTool(name: "list_unique_values", input: ["field": "merchant"])
        let values = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [[String: Any]]
        let names = values.map { $0["value"] as! String }
        XCTAssertTrue(names.contains("McDonald's"))
        XCTAssertTrue(names.contains("Starbucks"))
    }

    func test_listPaymentMethods() throws {
        let json = try service.executeTool(name: "list_unique_values", input: ["field": "payment_method"])
        let values = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [[String: Any]]
        let names = values.map { $0["value"] as! String }
        XCTAssertTrue(names.contains("Credit Card"))
        XCTAssertTrue(names.contains("Debit Card"))
    }

    // MARK: - get_date_range

    func test_getDateRange() throws {
        let json = try service.executeTool(name: "get_date_range", input: [:])
        let result = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [String: Any]
        XCTAssertEqual(result["earliest_date"] as? String, "2026-01-05")
        XCTAssertEqual(result["latest_date"] as? String, "2026-02-01")
        XCTAssertEqual(result["total_transactions"] as? Int, 11)
    }

    // MARK: - executeTool dispatch

    func test_unknownTool() {
        XCTAssertThrowsError(try service.executeTool(name: "nonexistent", input: [:])) { error in
            XCTAssertTrue(error is QueryError)
        }
    }

    func test_missingRequiredParam() {
        XCTAssertThrowsError(try service.executeTool(name: "list_unique_values", input: [:])) { error in
            XCTAssertTrue(error is QueryError)
        }
    }

    func test_invalidFieldParam() {
        XCTAssertThrowsError(try service.executeTool(name: "list_unique_values", input: ["field": "invalid"])) { error in
            XCTAssertTrue(error is QueryError)
        }
    }

    // MARK: - Helpers

    private func execute(_ tool: String, _ input: [String: Any]) throws -> [String: Any] {
        let json = try service.executeTool(name: tool, input: input)
        return try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [String: Any]
    }
}
