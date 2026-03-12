import Foundation
import GenerativeUIDSL

actor ClaudeService {
    static let shared = ClaudeService(apiKey: Secrets.claudeAPIKey)

    private let apiKey: String
    private let model = "claude-sonnet-4-20250514"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Maximum number of retry attempts when Claude returns invalid JSON
    private let maxRetries = 2

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func sendQuery(prompt: String, csvContent: String) async throws -> UIResponse {
        let systemPrompt = buildSystemPrompt(csvContent: csvContent)

        // First attempt
        let jsonString = try await callClaude(systemPrompt: systemPrompt, messages: [
            ["role": "user", "content": prompt]
        ])

        let cleanJSON = ClaudeService.extractJSON(from: jsonString)

        // Try to decode, and if it fails, retry with error feedback
        return try await decodeWithRetry(
            json: cleanJSON,
            systemPrompt: systemPrompt,
            originalPrompt: prompt,
            attempt: 0
        )
    }

    // MARK: - Decode with LLM Error Recovery

    private func decodeWithRetry(
        json: String,
        systemPrompt: String,
        originalPrompt: String,
        attempt: Int
    ) async throws -> UIResponse {
        guard let jsonData = json.data(using: .utf8) else {
            throw ClaudeError.invalidJSON(detail: "Could not convert response to UTF-8 data")
        }

        // Try decoding with diagnostics
        let (response, diagnostics, rawError) = decodeUIResponseWithDiagnostics(from: jsonData)

        if let response = response {
            // Decode succeeded — check if there are issues worth fixing
            if diagnostics.hasIssues && attempt < maxRetries {
                // Re-prompt Claude to fix the issues
                let fixPrompt = buildFixPrompt(
                    originalPrompt: originalPrompt,
                    currentJSON: json,
                    diagnostics: diagnostics
                )

                let fixedJSON = try await callClaude(systemPrompt: systemPrompt, messages: [
                    ["role": "user", "content": originalPrompt],
                    ["role": "assistant", "content": json],
                    ["role": "user", "content": fixPrompt]
                ])

                let cleanFixed = ClaudeService.extractJSON(from: fixedJSON)
                return try await decodeWithRetry(
                    json: cleanFixed,
                    systemPrompt: systemPrompt,
                    originalPrompt: originalPrompt,
                    attempt: attempt + 1
                )
            }

            // Log diagnostics if any, but return the (partially valid) response
            if diagnostics.hasIssues {
                print("[GenerativeUI] Response decoded with issues: \(diagnostics.summary)")
            }
            return response
        }

        // Full decode failure
        guard attempt < maxRetries else {
            throw ClaudeError.invalidJSON(detail: "Failed after \(maxRetries) retry attempts. Last error: \(rawError?.localizedDescription ?? "unknown")")
        }

        // Build error recovery prompt
        let errorDetail = describeDecodingError(rawError)
        let retryPrompt = buildRetryPrompt(
            originalPrompt: originalPrompt,
            failedJSON: json,
            errorDetail: errorDetail
        )

        let retriedJSON = try await callClaude(systemPrompt: systemPrompt, messages: [
            ["role": "user", "content": originalPrompt],
            ["role": "assistant", "content": json],
            ["role": "user", "content": retryPrompt]
        ])

        let cleanRetried = ClaudeService.extractJSON(from: retriedJSON)
        return try await decodeWithRetry(
            json: cleanRetried,
            systemPrompt: systemPrompt,
            originalPrompt: originalPrompt,
            attempt: attempt + 1
        )
    }

    // MARK: - Claude API Call

    private func callClaude(systemPrompt: String, messages: [[String: String]]) async throws -> String {
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": messages
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

        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let textBlock = claudeResponse.content.first(where: { $0.type == "text" }),
              let jsonString = textBlock.text else {
            throw ClaudeError.noContent
        }

        return jsonString
    }

    // MARK: - Error Recovery Prompts

    private func buildRetryPrompt(originalPrompt: String, failedJSON: String, errorDetail: String) -> String {
        """
        Your previous JSON response failed to parse. Here is the error:

        ERROR: \(errorDetail)

        Please fix the JSON and respond with ONLY the corrected JSON object. Do not include any explanation. \
        Make sure all required fields are present and all node types match the DSL specification exactly.
        """
    }

    private func buildFixPrompt(originalPrompt: String, currentJSON: String, diagnostics: DecodingDiagnostics) -> String {
        """
        Your response was partially parsed but had issues:

        \(diagnostics.summary)

        Please fix these issues and respond with ONLY the corrected JSON object. Do not include any explanation. \
        Use only the node types defined in the DSL specification. \
        For tabular data, use: {"type":"table", "title":"...", "headers":["Col1","Col2"], "rows":[["val1","val2"]]}. \
        For line charts, use variant "line" instead of "bar".
        """
    }

    private func describeDecodingError(_ error: Error?) -> String {
        guard let error = error else { return "Unknown decoding error" }

        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let context):
                return "Missing required key '\(key.stringValue)' at path: \(context.codingPath.map(\.stringValue).joined(separator: ".")). \(context.debugDescription)"
            case .typeMismatch(let type, let context):
                return "Type mismatch: expected \(type) at path: \(context.codingPath.map(\.stringValue).joined(separator: ".")). \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                return "Missing value of type \(type) at path: \(context.codingPath.map(\.stringValue).joined(separator: ".")). \(context.debugDescription)"
            case .dataCorrupted(let context):
                return "Data corrupted at path: \(context.codingPath.map(\.stringValue).joined(separator: ".")). \(context.debugDescription)"
            @unknown default:
                return "Decoding error: \(decodingError.localizedDescription)"
            }
        }

        return error.localizedDescription
    }

    // MARK: - System Prompt

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
        - stat: {"type":"stat", "label":"Total", "value":"$54", "color":"red", "size":"large|small", "icon":"dollarsign.circle"}
        - image: {"type":"image", "system_name":"cart.fill", "color":"blue", "size":"small|medium|large|xlarge"}
        - badge: {"type":"badge", "text":"Food & Dining", "color":"orange"}
        - progress: {"type":"progress", "value":75, "total":100, "label":"Budget Used", "color":"green"}

        CONTAINER NODES:
        - card: {"type":"card", "color":"blue", "padding":16, "cornerRadius":12, "child":{...single node}}
        - list: {"type":"list", "items":[...nodes]}  (renders items with dividers between them)

        TABLE NODE:
        - table: {"type":"table", "title":"Transaction List", "headers":["Date","Merchant","Amount"], "rows":[["Jan 5","McDonald's","$13"],["Jan 7","Starbucks","$7"]]}

        CHART NODE:
        - chart: {"type":"chart", "variant":"bar|pie|line", "title":"Spending by Category", "data":[{"label":"Food","value":120.5,"color":"orange"}, ...]}

        UTILITY NODES:
        - divider: {"type":"divider"}
        - spacer: {"type":"spacer"}

        DESIGN PRINCIPLES:
        - Be creative with layouts! Combine hstack/vstack/card to create rich, varied UIs.
        - Use cards to group related information visually.
        - Use hstacks to place stats side-by-side for comparison.
        - Use badges for categories or status labels.
        - Use progress bars for budget comparisons or ratios.
        - Use tables for displaying transaction lists or comparisons with rows and columns.
        - Use line charts for trends over time.
        - Use SF Symbols (system_name) for icons — e.g., "cart.fill", "dollarsign.circle", "fork.knife", "car.fill", "heart.fill", "tv.fill", "phone.fill", "house.fill".
        - Vary your layouts based on the question — don't always use the same pattern.
        - Use color meaningfully: red for high spending, green for savings, orange for warnings.
        - The root layout node should typically be a vstack.

        RULES:
        - ONLY use data from the provided CSV. Never invent transactions.
        - Format currency as whole dollars with no decimals (e.g., "$491" not "$490.55"). Round to the nearest dollar.
        - Format dates as "Mon D, YYYY" (e.g., "Jan 5, 2026").
        - Respond with ONLY the JSON object. No other text.
        - Keep layouts reasonably sized — don't render every single transaction if there are many; summarize and show top items.
        - Only use node types defined above. Do NOT use types like "summary_card", "transaction_table", etc.
        """
    }

    /// Extract JSON from a string that might be wrapped in markdown code blocks
    static func extractJSON(from text: String) -> String {
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
    case invalidJSON(detail: String)

    var errorDescription: String? {
        switch self {
        case .apiError(let message): return "API error: \(message)"
        case .noContent: return "No content in response"
        case .invalidJSON(let detail): return "Invalid JSON: \(detail)"
        }
    }
}
