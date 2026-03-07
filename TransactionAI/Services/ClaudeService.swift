import Foundation

actor ClaudeService {
    static let shared = ClaudeService()

    private let apiKey = Secrets.claudeAPIKey
    private let model = "claude-sonnet-4-20250514"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func sendQuery(prompt: String, csvContent: String) async throws -> UIResponse {
        let systemPrompt = buildSystemPrompt(csvContent: csvContent)

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.apiError(body)
        }

        // Parse the Claude response to extract the JSON content
        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let textBlock = claudeResponse.content.first(where: { $0.type == "text" }),
              let jsonString = textBlock.text else {
            throw ClaudeError.noContent
        }

        // Extract JSON from the response (handle markdown code blocks)
        let cleanJSON = extractJSON(from: jsonString)

        guard let jsonData = cleanJSON.data(using: .utf8) else {
            throw ClaudeError.invalidJSON
        }

        return try JSONDecoder().decode(UIResponse.self, from: jsonData)
    }

    private func buildSystemPrompt(csvContent: String) -> String {
        """
        You are a financial data assistant embedded in an iOS app. You generate native UI layouts using a recursive DSL.

        Here is the user's transaction data in CSV format:
        ```
        \(csvContent)
        ```

        You MUST respond with ONLY valid JSON (no markdown, no explanation, no code blocks) matching this schema:

        {
          "title": "Short title",
          "layout": { /* a single root UINode */ },
          "spoken_summary": "Brief natural language summary"
        }

        The "layout" field is a recursive UINode tree. Available node types:

        LAYOUT NODES (contain children):
        - vstack: {"type":"vstack", "spacing":12, "alignment":"leading|center|trailing", "children":[...nodes]}
        - hstack: {"type":"hstack", "spacing":8, "alignment":"top|center|bottom", "children":[...nodes]}
        - zstack: {"type":"zstack", "alignment":"center", "children":[...nodes]}

        CONTENT NODES:
        - text: {"type":"text", "content":"Hello", "style":"largeTitle|title|title2|title3|headline|subheadline|body|caption|caption2|footnote", "color":"red|blue|green|orange|purple|pink|gray|secondary|primary", "weight":"bold|semibold|medium|regular|light|heavy"}
        - stat: {"type":"stat", "label":"Total", "value":"$54.49", "color":"red", "size":"large|small", "icon":"dollarsign.circle"}
        - image: {"type":"image", "system_name":"cart.fill", "color":"blue", "size":"small|medium|large|xlarge"}
        - badge: {"type":"badge", "text":"Food & Dining", "color":"orange"}
        - progress: {"type":"progress", "value":75, "total":100, "label":"Budget Used", "color":"green"}

        CONTAINER NODES:
        - card: {"type":"card", "color":"blue", "padding":16, "cornerRadius":12, "child":{...single node}}
        - list: {"type":"list", "items":[...nodes]}  (renders items with dividers between them)

        CHART NODE:
        - chart: {"type":"chart", "variant":"bar|pie", "title":"Spending by Category", "data":[{"label":"Food","value":120.5,"color":"orange"}, ...]}

        UTILITY NODES:
        - divider: {"type":"divider"}
        - spacer: {"type":"spacer"}

        DESIGN PRINCIPLES:
        - Be creative with layouts! Combine hstack/vstack/card to create rich, varied UIs.
        - Use cards to group related information visually.
        - Use hstacks to place stats side-by-side for comparison.
        - Use badges for categories or status labels.
        - Use progress bars for budget comparisons or ratios.
        - Use SF Symbols (system_name) for icons — e.g., "cart.fill", "dollarsign.circle", "fork.knife", "car.fill", "heart.fill", "tv.fill", "phone.fill", "house.fill".
        - Vary your layouts based on the question — don't always use the same pattern.
        - For transaction lists, use list with hstack rows showing date, merchant/notes, and amount.
        - Use color meaningfully: red for high spending, green for savings, orange for warnings.
        - The root layout node should typically be a vstack.

        RULES:
        - ONLY use data from the provided CSV. Never invent transactions.
        - Format currency with $ and 2 decimal places.
        - Format dates as "Mon D, YYYY" (e.g., "Jan 5, 2026").
        - Respond with ONLY the JSON object. No other text.
        - Keep layouts reasonably sized — don't render every single transaction if there are many; summarize and show top items.
        """
    }

    /// Extract JSON from a string that might be wrapped in markdown code blocks
    private func extractJSON(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove ```json ... ``` wrapper if present
        if cleaned.hasPrefix("```") {
            if let startRange = cleaned.range(of: "\n") {
                cleaned = String(cleaned[startRange.upperBound...])
            }
            if let endRange = cleaned.range(of: "```", options: .backwards) {
                cleaned = String(cleaned[..<endRange.lowerBound])
            }
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Claude API Response Models

private struct ClaudeResponse: Codable {
    let content: [ContentBlock]
}

private struct ContentBlock: Codable {
    let type: String
    let text: String?
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case apiError(String)
    case noContent
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .apiError(let message): return "API error: \(message)"
        case .noContent: return "No content in response"
        case .invalidJSON: return "Could not parse response as JSON"
        }
    }
}
