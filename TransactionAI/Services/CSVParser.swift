import Foundation

struct CSVParser {
    /// Parse the bundled transactions.csv into Transaction models
    static func parseTransactions() -> [Transaction] {
        guard let url = Bundle.main.url(forResource: "transactions", withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("Failed to load transactions.csv")
            return []
        }
        return parse(csv: content)
    }

    /// Parse a CSV string into Transaction models
    static func parse(csv content: String) -> [Transaction] {
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard lines.count > 1 else { return [] }

        // Skip header row
        return lines.dropFirst().compactMap { line in
            let fields = parseCSVLine(line)
            guard fields.count >= 6,
                  let date = Transaction.csvDateFormatter.date(from: fields[0]),
                  let amount = Double(fields[3]) else {
                return nil
            }

            return Transaction(
                id: UUID(),
                date: date,
                merchant: fields[1],
                category: fields[2],
                amount: amount,
                paymentMethod: fields[4],
                notes: fields[5]
            )
        }
    }

    /// Handle basic CSV parsing (handles fields with commas in quotes)
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    /// Return the raw CSV content for sending to the LLM
    static func rawCSVContent() -> String {
        guard let url = Bundle.main.url(forResource: "transactions", withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return content
    }
}
