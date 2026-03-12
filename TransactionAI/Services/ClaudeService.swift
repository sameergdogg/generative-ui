import Foundation
import GenerativeUIDSL

actor ClaudeService {
    static let shared = ClaudeService(
        apiKey: Secrets.claudeAPIKey,
        transactions: CSVParser.parseTransactions()
    )

    private let apiKey: String
    private let model = "claude-sonnet-4-20250514"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let queryService: TransactionQueryService

    /// Maximum number of retry attempts when Claude returns invalid JSON
    private let maxRetries = 2
    /// Maximum number of tool-use round trips
    private let maxToolRounds = 10

    init(apiKey: String, transactions: [Transaction]) {
        self.apiKey = apiKey
        self.queryService = TransactionQueryService(transactions: transactions)
    }

    func sendQuery(prompt: String) async throws -> UIResponse {
        let systemPrompt = buildSystemPrompt()
        let tools = Self.buildToolDefinitions()

        // Tool-use conversation loop
        var messages: [[String: Any]] = [
            ["role": "user", "content": prompt]
        ]

        for _ in 0..<maxToolRounds {
            let response = try await callClaude(
                systemPrompt: systemPrompt,
                messages: messages,
                tools: tools
            )

            if response.stopReason == "tool_use" {
                // Extract tool_use blocks and execute them
                let toolUseBlocks = response.content.filter { $0.type == "tool_use" }
                guard !toolUseBlocks.isEmpty else {
                    throw ClaudeError.noContent
                }

                // Append the full assistant message (with all content blocks)
                let assistantContent: [[String: Any]] = response.content.map { block in
                    var dict: [String: Any] = ["type": block.type]
                    if let text = block.text { dict["text"] = text }
                    if let id = block.id { dict["id"] = id }
                    if let name = block.name { dict["name"] = name }
                    if let input = block.input { dict["input"] = input }
                    return dict
                }
                messages.append(["role": "assistant", "content": assistantContent])

                // Execute each tool and build tool_result blocks
                var toolResults: [[String: Any]] = []
                for block in toolUseBlocks {
                    guard let toolId = block.id, let toolName = block.name else { continue }
                    let toolInput = block.input ?? [:]

                    let resultContent: String
                    do {
                        resultContent = try queryService.executeTool(name: toolName, input: toolInput)
                    } catch {
                        resultContent = "{\"error\": \"\(error.localizedDescription)\"}"
                    }

                    toolResults.append([
                        "type": "tool_result",
                        "tool_use_id": toolId,
                        "content": resultContent
                    ])
                }

                messages.append(["role": "user", "content": toolResults])
            } else {
                // end_turn — extract text and parse as UI DSL
                guard let textBlock = response.content.first(where: { $0.type == "text" }),
                      let jsonString = textBlock.text else {
                    throw ClaudeError.noContent
                }

                let cleanJSON = ClaudeService.extractJSON(from: jsonString)
                return try await decodeWithRetry(
                    json: cleanJSON,
                    systemPrompt: systemPrompt,
                    originalPrompt: prompt,
                    tools: tools,
                    attempt: 0
                )
            }
        }

        throw ClaudeError.apiError("Exceeded maximum tool-use rounds (\(maxToolRounds))")
    }

    // MARK: - Decode with LLM Error Recovery

    private func decodeWithRetry(
        json: String,
        systemPrompt: String,
        originalPrompt: String,
        tools: [[String: Any]],
        attempt: Int
    ) async throws -> UIResponse {
        guard let jsonData = json.data(using: .utf8) else {
            throw ClaudeError.invalidJSON(detail: "Could not convert response to UTF-8 data")
        }

        let (response, diagnostics, rawError) = decodeUIResponseWithDiagnostics(from: jsonData)

        if let response = response {
            if diagnostics.hasIssues && attempt < maxRetries {
                let fixPrompt = buildFixPrompt(
                    originalPrompt: originalPrompt,
                    currentJSON: json,
                    diagnostics: diagnostics
                )

                let fixResponse = try await callClaude(
                    systemPrompt: systemPrompt,
                    messages: [
                        ["role": "user", "content": originalPrompt],
                        ["role": "assistant", "content": json],
                        ["role": "user", "content": fixPrompt]
                    ],
                    tools: tools
                )

                if let textBlock = fixResponse.content.first(where: { $0.type == "text" }),
                   let fixedText = textBlock.text {
                    let cleanFixed = ClaudeService.extractJSON(from: fixedText)
                    return try await decodeWithRetry(
                        json: cleanFixed,
                        systemPrompt: systemPrompt,
                        originalPrompt: originalPrompt,
                        tools: tools,
                        attempt: attempt + 1
                    )
                }
            }

            if diagnostics.hasIssues {
                print("[GenerativeUI] Response decoded with issues: \(diagnostics.summary)")
            }
            return response
        }

        guard attempt < maxRetries else {
            throw ClaudeError.invalidJSON(detail: "Failed after \(maxRetries) retry attempts. Last error: \(rawError?.localizedDescription ?? "unknown")")
        }

        let errorDetail = describeDecodingError(rawError)
        let retryPrompt = buildRetryPrompt(
            originalPrompt: originalPrompt,
            failedJSON: json,
            errorDetail: errorDetail
        )

        let retryResponse = try await callClaude(
            systemPrompt: systemPrompt,
            messages: [
                ["role": "user", "content": originalPrompt],
                ["role": "assistant", "content": json],
                ["role": "user", "content": retryPrompt]
            ],
            tools: tools
        )

        if let textBlock = retryResponse.content.first(where: { $0.type == "text" }),
           let retriedText = textBlock.text {
            let cleanRetried = ClaudeService.extractJSON(from: retriedText)
            return try await decodeWithRetry(
                json: cleanRetried,
                systemPrompt: systemPrompt,
                originalPrompt: originalPrompt,
                tools: tools,
                attempt: attempt + 1
            )
        }

        throw ClaudeError.noContent
    }

    // MARK: - Claude API Call

    private func callClaude(
        systemPrompt: String,
        messages: [[String: Any]],
        tools: [[String: Any]]
    ) async throws -> ClaudeResponse {
        var requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": messages,
            "tools": tools
        ]

        // Only include tools if non-empty
        if tools.isEmpty {
            requestBody.removeValue(forKey: "tools")
        }

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

        // Parse with JSONSerialization since tool_use.input is arbitrary JSON
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArray = json["content"] as? [[String: Any]],
              let stopReason = json["stop_reason"] as? String else {
            throw ClaudeError.noContent
        }

        let blocks = contentArray.map { dict -> ContentBlock in
            ContentBlock(
                type: dict["type"] as? String ?? "unknown",
                text: dict["text"] as? String,
                id: dict["id"] as? String,
                name: dict["name"] as? String,
                input: dict["input"] as? [String: Any]
            )
        }

        return ClaudeResponse(content: blocks, stopReason: stopReason)
    }

    // MARK: - Tool Definitions

    static func buildToolDefinitions() -> [[String: Any]] {
        [
            [
                "name": "filter_transactions",
                "description": "Search and filter transactions. Returns matching transactions with their details. Use this to find specific transactions by merchant, category, date range, or amount range.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "merchant": [
                            "type": "string",
                            "description": "Filter by merchant name (substring match, case-insensitive)"
                        ],
                        "category": [
                            "type": "string",
                            "description": "Filter by exact category (case-insensitive)"
                        ],
                        "payment_method": [
                            "type": "string",
                            "description": "Filter by payment method (case-insensitive)"
                        ],
                        "date_from": [
                            "type": "string",
                            "description": "Start date inclusive (YYYY-MM-DD)"
                        ],
                        "date_to": [
                            "type": "string",
                            "description": "End date inclusive (YYYY-MM-DD)"
                        ],
                        "min_amount": [
                            "type": "number",
                            "description": "Minimum transaction amount"
                        ],
                        "max_amount": [
                            "type": "number",
                            "description": "Maximum transaction amount"
                        ],
                        "limit": [
                            "type": "integer",
                            "description": "Maximum number of transactions to return (default 20)"
                        ],
                        "sort_by": [
                            "type": "string",
                            "enum": ["date", "amount", "merchant"],
                            "description": "Sort field (default: date)"
                        ],
                        "sort_order": [
                            "type": "string",
                            "enum": ["asc", "desc"],
                            "description": "Sort order (default: desc)"
                        ]
                    ] as [String: Any],
                    "required": [] as [String]
                ] as [String: Any]
            ],
            [
                "name": "aggregate_spending",
                "description": "Compute spending totals, counts, and averages, optionally grouped by category, merchant, payment method, month, or week. Use this for summary statistics and comparisons.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "group_by": [
                            "type": "string",
                            "enum": ["category", "merchant", "payment_method", "month", "week"],
                            "description": "Group results by this field. If omitted, returns a single aggregate over all matching transactions."
                        ],
                        "merchant": [
                            "type": "string",
                            "description": "Filter by merchant name (substring match)"
                        ],
                        "category": [
                            "type": "string",
                            "description": "Filter by exact category"
                        ],
                        "payment_method": [
                            "type": "string",
                            "description": "Filter by payment method"
                        ],
                        "date_from": [
                            "type": "string",
                            "description": "Start date inclusive (YYYY-MM-DD)"
                        ],
                        "date_to": [
                            "type": "string",
                            "description": "End date inclusive (YYYY-MM-DD)"
                        ],
                        "min_amount": [
                            "type": "number",
                            "description": "Minimum amount filter"
                        ],
                        "max_amount": [
                            "type": "number",
                            "description": "Maximum amount filter"
                        ],
                        "limit": [
                            "type": "integer",
                            "description": "Limit number of groups returned"
                        ],
                        "sort_by_value": [
                            "type": "boolean",
                            "description": "Sort groups by total (desc) if true, alphabetically if false. Default: true"
                        ]
                    ] as [String: Any],
                    "required": [] as [String]
                ] as [String: Any]
            ],
            [
                "name": "list_unique_values",
                "description": "List all unique values for a given field with their occurrence counts. Use this to discover what categories, merchants, or payment methods exist in the data.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "field": [
                            "type": "string",
                            "enum": ["category", "merchant", "payment_method"],
                            "description": "The field to list unique values for"
                        ]
                    ] as [String: Any],
                    "required": ["field"]
                ] as [String: Any]
            ],
            [
                "name": "get_date_range",
                "description": "Get the date range and total count of the transaction dataset. Use this to understand the scope of available data.",
                "input_schema": [
                    "type": "object",
                    "properties": [:] as [String: Any],
                    "required": [] as [String]
                ] as [String: Any]
            ]
        ]
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

    private func buildSystemPrompt() -> String {
        """
        You are a financial data assistant embedded in an iOS app. You have access to tools \
        that query the user's transaction data. Use these tools to get the data you need \
        before generating the UI layout.

        WORKFLOW:
        1. Use the available tools to query the data you need.
        2. You may call multiple tools if needed to gather all required data.
        3. Once you have all the data, respond with ONLY the UIResponse JSON.

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
        - ONLY use data returned by tool calls. Never invent transactions or numbers.
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

private struct ClaudeResponse {
    let content: [ContentBlock]
    let stopReason: String
}

private struct ContentBlock {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: [String: Any]?
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
