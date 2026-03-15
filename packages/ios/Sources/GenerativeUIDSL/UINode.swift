import Foundation
import SwiftUI

/// A recursive UI node that the LLM generates to describe arbitrary layouts
public indirect enum UINode: Codable, Identifiable {
    case vstack(VStackNode)
    case hstack(HStackNode)
    case zstack(ZStackNode)
    case text(TextNode)
    case stat(StatNode)
    case chart(ChartNode)
    case list(ListNode)
    case table(TableNode)
    case divider(id: String)
    case spacer(id: String)
    case image(ImageNode)
    case badge(BadgeNode)
    case card(CardNode)
    case progress(ProgressNode)

    public var id: String {
        switch self {
        case .vstack(let n): return n.id
        case .hstack(let n): return n.id
        case .zstack(let n): return n.id
        case .text(let n): return n.id
        case .stat(let n): return n.id
        case .chart(let n): return n.id
        case .list(let n): return n.id
        case .table(let n): return n.id
        case .divider(let id): return id
        case .spacer(let id): return id
        case .image(let n): return n.id
        case .badge(let n): return n.id
        case .card(let n): return n.id
        case .progress(let n): return n.id
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "vstack":
            self = .vstack(try VStackNode(from: decoder))
        case "hstack":
            self = .hstack(try HStackNode(from: decoder))
        case "zstack":
            self = .zstack(try ZStackNode(from: decoder))
        case "text":
            self = .text(try TextNode(from: decoder))
        case "stat":
            self = .stat(try StatNode(from: decoder))
        case "chart":
            self = .chart(try ChartNode(from: decoder))
        case "list":
            self = .list(try ListNode(from: decoder))
        case "table":
            self = .table(try TableNode(from: decoder))
        case "divider":
            self = .divider(id: UUID().uuidString)
        case "spacer":
            self = .spacer(id: UUID().uuidString)
        case "image":
            self = .image(try ImageNode(from: decoder))
        case "badge":
            self = .badge(try BadgeNode(from: decoder))
        case "card":
            self = .card(try CardNode(from: decoder))
        case "progress":
            self = .progress(try ProgressNode(from: decoder))
        default:
            // Fallback: render as text with the type name
            self = .text(TextNode(content: "Unknown: \(type)", style: "caption", color: "secondary", weight: nil, maxLines: nil))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .vstack(let n):
            try container.encode("vstack", forKey: .type)
            try n.encode(to: encoder)
        case .hstack(let n):
            try container.encode("hstack", forKey: .type)
            try n.encode(to: encoder)
        case .zstack(let n):
            try container.encode("zstack", forKey: .type)
            try n.encode(to: encoder)
        case .text(let n):
            try container.encode("text", forKey: .type)
            try n.encode(to: encoder)
        case .stat(let n):
            try container.encode("stat", forKey: .type)
            try n.encode(to: encoder)
        case .chart(let n):
            try container.encode("chart", forKey: .type)
            try n.encode(to: encoder)
        case .list(let n):
            try container.encode("list", forKey: .type)
            try n.encode(to: encoder)
        case .table(let n):
            try container.encode("table", forKey: .type)
            try n.encode(to: encoder)
        case .divider:
            try container.encode("divider", forKey: .type)
        case .spacer:
            try container.encode("spacer", forKey: .type)
        case .image(let n):
            try container.encode("image", forKey: .type)
            try n.encode(to: encoder)
        case .badge(let n):
            try container.encode("badge", forKey: .type)
            try n.encode(to: encoder)
        case .card(let n):
            try container.encode("card", forKey: .type)
            try n.encode(to: encoder)
        case .progress(let n):
            try container.encode("progress", forKey: .type)
            try n.encode(to: encoder)
        }
    }
}

// MARK: - Fault-Tolerant Child Decoding

/// Decodes an array of UINodes, skipping any that fail to decode instead of failing the whole array.
/// Returns the successfully decoded nodes and any errors encountered.
public struct FaultTolerantNodeArray: Codable {
    public let nodes: [UINode]
    public let errors: [DecodingError]

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var nodes: [UINode] = []
        var errors: [DecodingError] = []

        while !container.isAtEnd {
            do {
                let node = try container.decode(UINode.self)
                nodes.append(node)
            } catch let error as DecodingError {
                errors.append(error)
                // Skip the failed element by decoding it as a generic JSON value
                _ = try? container.decode(AnyCodable.self)
            }
        }

        self.nodes = nodes
        self.errors = errors
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for node in nodes {
            try container.encode(node)
        }
    }
}

/// A type-erased Codable wrapper for skipping invalid JSON elements during fault-tolerant decoding
private struct AnyCodable: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { return }
        if let _ = try? container.decode(Bool.self) { return }
        if let _ = try? container.decode(Int.self) { return }
        if let _ = try? container.decode(Double.self) { return }
        if let _ = try? container.decode(String.self) { return }
        if let _ = try? container.decode([AnyCodable].self) { return }
        if let _ = try? container.decode([String: AnyCodable].self) { return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
    }

    func encode(to encoder: Encoder) throws {
        // No-op: used only for decoding
    }
}

// MARK: - Decoding Diagnostics

/// Collects all issues found during a UINode tree decode
public struct DecodingDiagnostics {
    public var skippedNodes: [(path: String, error: String)] = []
    public var unknownTypes: [String] = []
    public var warnings: [String] = []

    public var hasIssues: Bool {
        !skippedNodes.isEmpty || !unknownTypes.isEmpty || !warnings.isEmpty
    }

    public var summary: String {
        var parts: [String] = []
        if !skippedNodes.isEmpty {
            parts.append("\(skippedNodes.count) node(s) failed to decode and were skipped: \(skippedNodes.map { "\($0.path): \($0.error)" }.joined(separator: "; "))")
        }
        if !unknownTypes.isEmpty {
            parts.append("Unknown node types encountered: \(unknownTypes.joined(separator: ", "))")
        }
        if !warnings.isEmpty {
            parts.append("Warnings: \(warnings.joined(separator: "; "))")
        }
        return parts.joined(separator: "\n")
    }
}

/// Decode a UIResponse with fault tolerance and diagnostics
public func decodeUIResponseWithDiagnostics(from data: Data) -> (response: UIResponse?, diagnostics: DecodingDiagnostics, rawError: Error?) {
    var diagnostics = DecodingDiagnostics()

    do {
        let response = try JSONDecoder().decode(UIResponse.self, from: data)
        // Walk the tree to find unknown types and collect diagnostics
        collectDiagnostics(from: response.layout, path: "layout", diagnostics: &diagnostics)
        return (response, diagnostics, nil)
    } catch {
        return (nil, diagnostics, error)
    }
}

private func collectDiagnostics(from node: UINode, path: String, diagnostics: inout DecodingDiagnostics) {
    switch node {
    case .text(let t):
        if t.content.hasPrefix("Unknown: ") {
            let typeName = String(t.content.dropFirst("Unknown: ".count))
            diagnostics.unknownTypes.append(typeName)
        }
    case .vstack(let n):
        for (i, child) in n.children.enumerated() {
            collectDiagnostics(from: child, path: "\(path).children[\(i)]", diagnostics: &diagnostics)
        }
    case .hstack(let n):
        for (i, child) in n.children.enumerated() {
            collectDiagnostics(from: child, path: "\(path).children[\(i)]", diagnostics: &diagnostics)
        }
    case .zstack(let n):
        for (i, child) in n.children.enumerated() {
            collectDiagnostics(from: child, path: "\(path).children[\(i)]", diagnostics: &diagnostics)
        }
    case .card(let n):
        collectDiagnostics(from: n.child, path: "\(path).child", diagnostics: &diagnostics)
    case .list(let n):
        for (i, item) in n.items.enumerated() {
            collectDiagnostics(from: item, path: "\(path).items[\(i)]", diagnostics: &diagnostics)
        }
    case .table(let n):
        if n.headers.isEmpty { diagnostics.warnings.append("Table at \(path) has no headers") }
        if n.rows.isEmpty { diagnostics.warnings.append("Table at \(path) has no rows") }
    case .chart(let n):
        if n.data.isEmpty { diagnostics.warnings.append("Chart at \(path) has no data") }
    default:
        break
    }
}

// MARK: - Layout Nodes

public struct VStackNode: Codable {
    public let id: String
    public let spacing: CGFloat?
    public let alignment: String?
    public let children: [UINode]

    public init(id: String = UUID().uuidString, spacing: CGFloat? = nil, alignment: String? = nil, children: [UINode]) {
        self.id = id
        self.spacing = spacing
        self.alignment = alignment
        self.children = children
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.spacing = try container.decodeIfPresent(CGFloat.self, forKey: .spacing)
        self.alignment = try container.decodeIfPresent(String.self, forKey: .alignment)
        // Fault-tolerant child decoding
        let tolerant = try container.decode(FaultTolerantNodeArray.self, forKey: .children)
        self.children = tolerant.nodes
    }

    enum CodingKeys: String, CodingKey {
        case spacing, alignment, children
    }
}

public struct HStackNode: Codable {
    public let id: String
    public let spacing: CGFloat?
    public let alignment: String?
    public let children: [UINode]

    public init(id: String = UUID().uuidString, spacing: CGFloat? = nil, alignment: String? = nil, children: [UINode]) {
        self.id = id
        self.spacing = spacing
        self.alignment = alignment
        self.children = children
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.spacing = try container.decodeIfPresent(CGFloat.self, forKey: .spacing)
        self.alignment = try container.decodeIfPresent(String.self, forKey: .alignment)
        let tolerant = try container.decode(FaultTolerantNodeArray.self, forKey: .children)
        self.children = tolerant.nodes
    }

    enum CodingKeys: String, CodingKey {
        case spacing, alignment, children
    }
}

public struct ZStackNode: Codable {
    public let id: String
    public let alignment: String?
    public let children: [UINode]

    public init(id: String = UUID().uuidString, alignment: String? = nil, children: [UINode]) {
        self.id = id
        self.alignment = alignment
        self.children = children
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.alignment = try container.decodeIfPresent(String.self, forKey: .alignment)
        let tolerant = try container.decode(FaultTolerantNodeArray.self, forKey: .children)
        self.children = tolerant.nodes
    }

    enum CodingKeys: String, CodingKey {
        case alignment, children
    }
}

// MARK: - Content Nodes

public struct TextNode: Codable {
    public let id: String
    public let content: String
    public let style: String?
    public let color: String?
    public let weight: String?
    public let maxLines: Int?

    public init(content: String, style: String?, color: String?, weight: String?, maxLines: Int?) {
        self.id = UUID().uuidString
        self.content = content
        self.style = style
        self.color = color
        self.weight = weight
        self.maxLines = maxLines
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.content = try container.decode(String.self, forKey: .content)
        self.style = try container.decodeIfPresent(String.self, forKey: .style)
        self.color = try container.decodeIfPresent(String.self, forKey: .color)
        self.weight = try container.decodeIfPresent(String.self, forKey: .weight)
        self.maxLines = try container.decodeIfPresent(Int.self, forKey: .maxLines)
    }

    enum CodingKeys: String, CodingKey {
        case content, style, color, weight, maxLines
    }
}

public struct StatNode: Codable {
    public let id: String
    public let label: String
    public let value: String
    public let color: String?
    public let size: String?
    public let icon: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.label = try container.decode(String.self, forKey: .label)
        self.value = try container.decode(String.self, forKey: .value)
        self.color = try container.decodeIfPresent(String.self, forKey: .color)
        self.size = try container.decodeIfPresent(String.self, forKey: .size)
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon)
    }

    enum CodingKeys: String, CodingKey {
        case label, value, color, size, icon
    }
}

public struct ImageNode: Codable {
    public let id: String
    public let systemName: String
    public let color: String?
    public let size: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.systemName = try container.decode(String.self, forKey: .systemName)
        self.color = try container.decodeIfPresent(String.self, forKey: .color)
        self.size = try container.decodeIfPresent(String.self, forKey: .size)
    }

    enum CodingKeys: String, CodingKey {
        case systemName = "system_name"
        case color, size
    }
}

public struct BadgeNode: Codable {
    public let id: String
    public let text: String
    public let color: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.text = try container.decode(String.self, forKey: .text)
        self.color = try container.decodeIfPresent(String.self, forKey: .color)
    }

    enum CodingKeys: String, CodingKey {
        case text, color
    }
}

public struct CardNode: Codable {
    public let id: String
    public let color: String?
    public let padding: CGFloat?
    public let cornerRadius: CGFloat?
    public let child: UINode

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.color = try container.decodeIfPresent(String.self, forKey: .color)
        self.padding = try container.decodeIfPresent(CGFloat.self, forKey: .padding)
        self.cornerRadius = try container.decodeIfPresent(CGFloat.self, forKey: .cornerRadius)
        self.child = try container.decode(UINode.self, forKey: .child)
    }

    enum CodingKeys: String, CodingKey {
        case color, padding, cornerRadius, child
    }
}

public struct ProgressNode: Codable {
    public let id: String
    public let value: Double
    public let total: Double
    public let label: String?
    public let color: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.value = try container.decode(Double.self, forKey: .value)
        self.total = try container.decodeIfPresent(Double.self, forKey: .total) ?? 1.0
        self.label = try container.decodeIfPresent(String.self, forKey: .label)
        self.color = try container.decodeIfPresent(String.self, forKey: .color)
    }

    enum CodingKeys: String, CodingKey {
        case value, total, label, color
    }
}

// MARK: - Chart Node

public struct ChartNode: Codable {
    public let id: String
    public let variant: String // "bar", "pie", "line"
    public let title: String?
    public let data: [ChartDataPoint]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.variant = try container.decode(String.self, forKey: .variant)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.data = try container.decode([ChartDataPoint].self, forKey: .data)
    }

    enum CodingKeys: String, CodingKey {
        case variant, title, data
    }
}

public struct ChartDataPoint: Codable, Identifiable {
    public let id: String
    public let label: String
    public let value: Double
    public let color: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.label = try container.decode(String.self, forKey: .label)
        self.value = try container.decode(Double.self, forKey: .value)
        self.color = try container.decodeIfPresent(String.self, forKey: .color)
    }

    enum CodingKeys: String, CodingKey {
        case label, value, color
    }
}

// MARK: - List Node

public struct ListNode: Codable {
    public let id: String
    public let items: [UINode]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        let tolerant = try container.decode(FaultTolerantNodeArray.self, forKey: .items)
        self.items = tolerant.nodes
    }

    enum CodingKeys: String, CodingKey {
        case items
    }
}

// MARK: - Table Node

public struct TableNode: Codable {
    public let id: String
    public let title: String?
    public let headers: [String]
    public let rows: [[String]]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.headers = try container.decodeIfPresent([String].self, forKey: .headers) ?? []
        self.rows = try container.decodeIfPresent([[String]].self, forKey: .rows) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case title, headers, rows
    }
}

// MARK: - Color Resolver

public extension String {
    var resolvedColor: Color {
        switch self.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "gray", "grey": return .gray
        case "brown": return .brown
        case "cyan": return .cyan
        case "mint": return .mint
        case "teal": return .teal
        case "indigo": return .indigo
        case "white": return .white
        case "black": return .black
        case "primary": return .primary
        case "secondary": return .secondary
        default: return .primary
        }
    }
}
