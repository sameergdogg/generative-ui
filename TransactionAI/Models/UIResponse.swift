import Foundation

/// The top-level response from the LLM describing what UI to render
struct UIResponse: Codable {
    let title: String
    let components: [UIComponent]
    let spokenSummary: String

    enum CodingKeys: String, CodingKey {
        case title
        case components
        case spokenSummary = "spoken_summary"
    }
}

/// A single UI component the LLM wants to render
struct UIComponent: Codable, Identifiable {
    let id: UUID
    let type: ComponentType
    let data: ComponentData

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.type = try container.decode(ComponentType.self, forKey: .type)
        self.data = try container.decode(ComponentData.self, forKey: .data)
    }

    enum CodingKeys: String, CodingKey {
        case type, data
    }
}

enum ComponentType: String, Codable {
    case summaryCard = "summary_card"
    case transactionTable = "transaction_table"
    case barChart = "bar_chart"
    case metricGrid = "metric_grid"
}

/// Union type for all component data shapes
enum ComponentData: Codable {
    case summaryCard(SummaryCardData)
    case transactionTable(TransactionTableData)
    case barChart(BarChartData)
    case metricGrid(MetricGridData)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try each type — the parent UIComponent knows the type,
        // so we decode based on context in UIComponent
        if let data = try? container.decode(SummaryCardData.self),
           data.value != nil {
            self = .summaryCard(data)
        } else if let data = try? container.decode(TransactionTableData.self),
                  data.columns != nil {
            self = .transactionTable(data)
        } else if let data = try? container.decode(BarChartData.self),
                  data.bars != nil {
            self = .barChart(data)
        } else if let data = try? container.decode(MetricGridData.self),
                  data.metrics != nil {
            self = .metricGrid(data)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown component data")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .summaryCard(let data): try container.encode(data)
        case .transactionTable(let data): try container.encode(data)
        case .barChart(let data): try container.encode(data)
        case .metricGrid(let data): try container.encode(data)
        }
    }
}

// MARK: - Component Data Models

struct SummaryCardData: Codable {
    let title: String?
    let value: String?
    let subtitle: String?
}

struct TransactionTableData: Codable {
    let columns: [String]?
    let rows: [[String]]?
}

struct BarChartData: Codable {
    let label: String?
    let bars: [BarItem]?
}

struct BarItem: Codable, Identifiable {
    let id: UUID
    let name: String
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.value = try container.decode(Double.self, forKey: .value)
    }

    enum CodingKeys: String, CodingKey {
        case name, value
    }
}

struct MetricGridData: Codable {
    let metrics: [MetricItem]?
}

struct MetricItem: Codable, Identifiable {
    let id: UUID
    let label: String
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.label = try container.decode(String.self, forKey: .label)
        self.value = try container.decode(String.self, forKey: .value)
    }

    enum CodingKeys: String, CodingKey {
        case label, value
    }
}
