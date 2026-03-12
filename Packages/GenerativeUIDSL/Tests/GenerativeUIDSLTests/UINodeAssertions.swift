import Foundation
import XCTest
@testable import GenerativeUIDSL

// MARK: - Test Helpers

/// Decode a UINode from a JSON string
func decodeNode(from json: String) throws -> UINode {
    let data = json.data(using: .utf8)!
    return try JSONDecoder().decode(UINode.self, from: data)
}

/// Decode a UIResponse from a JSON string
func decodeUIResponse(from json: String) throws -> UIResponse {
    let data = json.data(using: .utf8)!
    return try JSONDecoder().decode(UIResponse.self, from: data)
}

/// Load a JSON fixture from the test bundle
func loadFixture(_ name: String) throws -> Data {
    let bundle = Bundle.module
    guard let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
        throw FixtureError.notFound(name)
    }
    return try Data(contentsOf: url)
}

/// Decode a UINode from a fixture file
func decodeNodeFromFixture(_ name: String) throws -> UINode {
    let data = try loadFixture(name)
    return try JSONDecoder().decode(UINode.self, from: data)
}

/// Decode a UIResponse from a fixture file
func decodeResponseFromFixture(_ name: String) throws -> UIResponse {
    let data = try loadFixture(name)
    return try JSONDecoder().decode(UIResponse.self, from: data)
}

enum FixtureError: Error {
    case notFound(String)
}

// MARK: - Tree Utilities

/// Recursively count all nodes in a UINode tree
func nodeCount(_ node: UINode) -> Int {
    switch node {
    case .vstack(let n):
        return 1 + n.children.map(nodeCount).reduce(0, +)
    case .hstack(let n):
        return 1 + n.children.map(nodeCount).reduce(0, +)
    case .zstack(let n):
        return 1 + n.children.map(nodeCount).reduce(0, +)
    case .card(let n):
        return 1 + nodeCount(n.child)
    case .list(let n):
        return 1 + n.items.map(nodeCount).reduce(0, +)
    case .text, .stat, .image, .badge, .progress, .divider, .spacer, .chart, .table:
        return 1
    }
}

/// Flatten all nodes in a UINode tree into an array
func flattenTree(_ node: UINode) -> [UINode] {
    var result = [node]
    switch node {
    case .vstack(let n):
        for child in n.children { result += flattenTree(child) }
    case .hstack(let n):
        for child in n.children { result += flattenTree(child) }
    case .zstack(let n):
        for child in n.children { result += flattenTree(child) }
    case .card(let n):
        result += flattenTree(n.child)
    case .list(let n):
        for item in n.items { result += flattenTree(item) }
    case .text, .stat, .image, .badge, .progress, .divider, .spacer, .chart, .table:
        break
    }
    return result
}

/// Get a string name for a node's type
func nodeTypeString(_ node: UINode) -> String {
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

/// Check if a node matches a given type string
func isNodeType(_ node: UINode, _ type: String) -> Bool {
    nodeTypeString(node) == type
}

/// Find all nodes of a given type in the tree
func findNodes(ofType type: String, in node: UINode) -> [UINode] {
    flattenTree(node).filter { isNodeType($0, type) }
}
