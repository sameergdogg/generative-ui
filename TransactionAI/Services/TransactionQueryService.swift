import Foundation

struct TransactionQueryService {
    let transactions: [Transaction]

    // MARK: - Tool Dispatch

    func executeTool(name: String, input: [String: Any]) throws -> String {
        let result: Any
        switch name {
        case "filter_transactions":
            result = try filterTransactions(input: input)
        case "aggregate_spending":
            result = try aggregateSpending(input: input)
        case "list_unique_values":
            result = try listUniqueValues(input: input)
        case "get_date_range":
            result = getDateRange()
        default:
            throw QueryError.unknownTool(name)
        }
        let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    // MARK: - Filter Transactions

    private func filterTransactions(input: [String: Any]) throws -> [String: Any] {
        var filtered = transactions

        if let merchant = input["merchant"] as? String, !merchant.isEmpty {
            filtered = filtered.filter { $0.merchant.localizedCaseInsensitiveContains(merchant) }
        }
        if let category = input["category"] as? String, !category.isEmpty {
            filtered = filtered.filter { $0.category.caseInsensitiveCompare(category) == .orderedSame }
        }
        if let method = input["payment_method"] as? String, !method.isEmpty {
            filtered = filtered.filter { $0.paymentMethod.caseInsensitiveCompare(method) == .orderedSame }
        }
        if let dateFrom = input["date_from"] as? String, let date = parseDate(dateFrom) {
            filtered = filtered.filter { $0.date >= date }
        }
        if let dateTo = input["date_to"] as? String, let date = parseDate(dateTo) {
            filtered = filtered.filter { $0.date <= date }
        }
        if let minAmount = input["min_amount"] as? Double {
            filtered = filtered.filter { $0.amount >= minAmount }
        } else if let minAmount = input["min_amount"] as? Int {
            filtered = filtered.filter { $0.amount >= Double(minAmount) }
        }
        if let maxAmount = input["max_amount"] as? Double {
            filtered = filtered.filter { $0.amount <= maxAmount }
        } else if let maxAmount = input["max_amount"] as? Int {
            filtered = filtered.filter { $0.amount <= Double(maxAmount) }
        }

        let totalMatching = filtered.count

        let sortBy = input["sort_by"] as? String ?? "date"
        let sortOrder = input["sort_order"] as? String ?? "desc"

        filtered.sort { a, b in
            let comparison: Bool
            switch sortBy {
            case "amount":
                comparison = a.amount < b.amount
            case "merchant":
                comparison = a.merchant.localizedCaseInsensitiveCompare(b.merchant) == .orderedAscending
            default: // "date"
                comparison = a.date < b.date
            }
            return sortOrder == "asc" ? comparison : !comparison
        }

        let limit = input["limit"] as? Int ?? 20
        let limited = Array(filtered.prefix(limit))

        let rows: [[String: Any]] = limited.map { t in
            [
                "date": formatDate(t.date),
                "merchant": t.merchant,
                "category": t.category,
                "amount": round(t.amount * 100) / 100,
                "payment_method": t.paymentMethod,
                "notes": t.notes
            ]
        }

        return [
            "transactions": rows,
            "total_matching": totalMatching
        ]
    }

    // MARK: - Aggregate Spending

    private func aggregateSpending(input: [String: Any]) throws -> Any {
        var filtered = transactions

        // Apply same filters as filter_transactions
        if let merchant = input["merchant"] as? String, !merchant.isEmpty {
            filtered = filtered.filter { $0.merchant.localizedCaseInsensitiveContains(merchant) }
        }
        if let category = input["category"] as? String, !category.isEmpty {
            filtered = filtered.filter { $0.category.caseInsensitiveCompare(category) == .orderedSame }
        }
        if let method = input["payment_method"] as? String, !method.isEmpty {
            filtered = filtered.filter { $0.paymentMethod.caseInsensitiveCompare(method) == .orderedSame }
        }
        if let dateFrom = input["date_from"] as? String, let date = parseDate(dateFrom) {
            filtered = filtered.filter { $0.date >= date }
        }
        if let dateTo = input["date_to"] as? String, let date = parseDate(dateTo) {
            filtered = filtered.filter { $0.date <= date }
        }
        if let minAmount = input["min_amount"] as? Double {
            filtered = filtered.filter { $0.amount >= minAmount }
        } else if let minAmount = input["min_amount"] as? Int {
            filtered = filtered.filter { $0.amount >= Double(minAmount) }
        }
        if let maxAmount = input["max_amount"] as? Double {
            filtered = filtered.filter { $0.amount <= maxAmount }
        } else if let maxAmount = input["max_amount"] as? Int {
            filtered = filtered.filter { $0.amount <= Double(maxAmount) }
        }

        guard let groupBy = input["group_by"] as? String else {
            // Ungrouped aggregation
            return computeMetrics(for: filtered)
        }

        // Grouped aggregation
        let grouped = Dictionary(grouping: filtered) { transaction -> String in
            switch groupBy {
            case "category":
                return transaction.category
            case "merchant":
                return transaction.merchant
            case "payment_method":
                return transaction.paymentMethod
            case "month":
                return monthKey(for: transaction.date)
            case "week":
                return weekKey(for: transaction.date)
            default:
                return "unknown"
            }
        }

        var groups: [[String: Any]] = grouped.map { key, txns in
            var entry = computeMetrics(for: txns)
            entry["group"] = key
            return entry
        }

        let sortByValue = input["sort_by_value"] as? Bool ?? true
        if sortByValue {
            groups.sort { ($0["total"] as? Double ?? 0) > ($1["total"] as? Double ?? 0) }
        } else {
            groups.sort { ($0["group"] as? String ?? "") < ($1["group"] as? String ?? "") }
        }

        if let limit = input["limit"] as? Int {
            return Array(groups.prefix(limit))
        }

        return groups
    }

    // MARK: - List Unique Values

    private func listUniqueValues(input: [String: Any]) throws -> [[String: Any]] {
        guard let field = input["field"] as? String else {
            throw QueryError.missingParameter("field")
        }

        let values: [String]
        switch field {
        case "category":
            values = transactions.map(\.category)
        case "merchant":
            values = transactions.map(\.merchant)
        case "payment_method":
            values = transactions.map(\.paymentMethod)
        default:
            throw QueryError.invalidParameter("field", field)
        }

        var counts: [String: Int] = [:]
        for value in values {
            counts[value, default: 0] += 1
        }

        return counts
            .map { ["value": $0.key, "count": $0.value] as [String: Any] }
            .sorted { ($0["count"] as? Int ?? 0) > ($1["count"] as? Int ?? 0) }
    }

    // MARK: - Get Date Range

    private func getDateRange() -> [String: Any] {
        guard !transactions.isEmpty else {
            return ["earliest_date": "", "latest_date": "", "total_transactions": 0]
        }
        let sorted = transactions.sorted { $0.date < $1.date }
        return [
            "earliest_date": formatDate(sorted.first!.date),
            "latest_date": formatDate(sorted.last!.date),
            "total_transactions": transactions.count
        ]
    }

    // MARK: - Helpers

    private func computeMetrics(for txns: [Transaction]) -> [String: Any] {
        let amounts = txns.map(\.amount)
        let total = amounts.reduce(0, +)
        let count = amounts.count
        return [
            "total": round(total * 100) / 100,
            "count": count,
            "average": count > 0 ? round(total / Double(count) * 100) / 100 : 0,
            "min": amounts.min() ?? 0,
            "max": amounts.max() ?? 0
        ]
    }

    private func parseDate(_ string: String) -> Date? {
        Transaction.csvDateFormatter.date(from: string)
    }

    private func formatDate(_ date: Date) -> String {
        Transaction.csvDateFormatter.string(from: date)
    }

    private func monthKey(for date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return String(format: "%04d-%02d", year, month)
    }

    private func weekKey(for date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", components.yearForWeekOfYear ?? 0, components.weekOfYear ?? 0)
    }
}

// MARK: - Errors

enum QueryError: LocalizedError {
    case unknownTool(String)
    case missingParameter(String)
    case invalidParameter(String, String)

    var errorDescription: String? {
        switch self {
        case .unknownTool(let name): return "Unknown tool: \(name)"
        case .missingParameter(let name): return "Missing required parameter: \(name)"
        case .invalidParameter(let name, let value): return "Invalid value '\(value)' for parameter '\(name)'"
        }
    }
}
