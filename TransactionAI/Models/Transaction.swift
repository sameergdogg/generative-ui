import Foundation

struct Transaction: Identifiable, Codable {
    let id: UUID
    let date: Date
    let merchant: String
    let category: String
    let amount: Double
    let paymentMethod: String
    let notes: String

    var formattedAmount: String {
        String(format: "$%.2f", amount)
    }

    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    static let csvDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
