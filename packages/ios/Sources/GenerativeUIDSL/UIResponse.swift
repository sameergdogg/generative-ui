import Foundation

/// The top-level response from the LLM describing what UI to render
public struct UIResponse: Codable {
    public let title: String
    public let layout: UINode
    public let spokenSummary: String

    enum CodingKeys: String, CodingKey {
        case title
        case layout
        case spokenSummary = "spoken_summary"
    }
}
