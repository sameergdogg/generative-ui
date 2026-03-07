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
        You are a financial data assistant embedded in an iOS app. The user will ask questions about their transactions.

        Here is their transaction data in CSV format:
        ```
        \(csvContent)
        ```

        You MUST respond with ONLY valid JSON (no markdown, no explanation, no code blocks) matching this exact schema:

        {
          "title": "Short title for the response",
          "components": [
            // One or more components from the types below
          ],
          "spoken_summary": "Brief natural language summary of the answer"
        }

        Available component types:

        1. summary_card - A single big stat
        {
          "type": "summary_card",
          "data": {
            "title": "Label for the stat",
            "value": "$123.45",
            "subtitle": "Additional context"
          }
        }

        2. transaction_table - A table of transactions
        {
          "type": "transaction_table",
          "data": {
            "columns": ["Date", "Amount", "Notes"],
            "rows": [["Jan 5", "$12.50", "Lunch"], ...]
          }
        }

        3. bar_chart - A bar chart comparing values
        {
          "type": "bar_chart",
          "data": {
            "label": "Chart title",
            "bars": [
              {"name": "Category A", "value": 123.45},
              {"name": "Category B", "value": 67.89}
            ]
          }
        }

        4. metric_grid - Multiple stats in a grid
        {
          "type": "metric_grid",
          "data": {
            "metrics": [
              {"label": "Total Spent", "value": "$500"},
              {"label": "Transactions", "value": "12"}
            ]
          }
        }

        Rules:
        - ONLY use data from the provided CSV. Never invent transactions.
        - Choose the best component type(s) for the question. You can combine multiple components.
        - For spending questions, a summary_card + transaction_table works well.
        - For comparison questions, use bar_chart.
        - For overview questions, use metric_grid.
        - Format currency values with $ and 2 decimal places.
        - Format dates as "Mon D, YYYY" (e.g., "Jan 5, 2026").
        - Respond with ONLY the JSON object. No other text.
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
