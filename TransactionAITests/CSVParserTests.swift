import XCTest
@testable import TransactionAI

final class CSVParserTests: XCTestCase {

    func test_parseValidCSV() {
        let csv = """
        date,merchant,category,amount,payment_method,notes
        2026-01-05,McDonald's,Food & Dining,12.50,Credit Card,Lunch
        2026-01-07,Starbucks,Food & Dining,6.75,Debit Card,Morning coffee
        """
        let transactions = CSVParser.parse(csv: csv)
        XCTAssertEqual(transactions.count, 2)
        XCTAssertEqual(transactions[0].merchant, "McDonald's")
        XCTAssertEqual(transactions[0].amount, 12.50)
        XCTAssertEqual(transactions[1].merchant, "Starbucks")
    }

    func test_parseEmptyCSV() {
        let transactions = CSVParser.parse(csv: "")
        XCTAssertTrue(transactions.isEmpty)
    }

    func test_parseHeaderOnly() {
        let csv = "date,merchant,category,amount,payment_method,notes"
        let transactions = CSVParser.parse(csv: csv)
        XCTAssertTrue(transactions.isEmpty)
    }
}
