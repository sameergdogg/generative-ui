# Generative UI Prototype - iOS SwiftUI App

## Concept
An iOS app powered by a CSV of transactions where users can ask natural language questions (e.g., "show me all expenses at McDonald's") and get rich, native SwiftUI UI responses instead of plain text.

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌───────────────┐     ┌────────────┐
│  User Prompt │ --> │  LLM (Claude)│ --> │ JSON Response │ --> │ SwiftUI    │
│  "Show me    │     │  - Filters   │     │ { type, data, │     │ Component  │
│   expenses   │     │    data      │     │   layout }    │     │ Renderer   │
│   at McD's"  │     │  - Picks UI  │     │               │     │            │
└─────────────┘     └──────────────┘     └───────────────┘     └────────────┘
```

## Tech Stack
- **iOS App**: SwiftUI (iOS 17+)
- **LLM**: Claude API (via Anthropic Swift SDK or REST)
- **Data**: Local CSV file of transactions
- **Min Xcode**: 15+

## Data Model

### Sample CSV (`transactions.csv`)
```
date,merchant,category,amount,payment_method,notes
2026-01-05,McDonald's,Food & Dining,12.50,Credit Card,Lunch
2026-01-07,Starbucks,Food & Dining,6.75,Debit Card,Morning coffee
2026-01-10,Shell Gas,Transportation,45.00,Credit Card,Gas fill-up
2026-01-12,McDonald's,Food & Dining,8.99,Credit Card,Drive-through
...
```

## UI Component Library

These are the SwiftUI components the LLM can choose from:

### 1. **TransactionTable**
- Scrollable list of transactions with columns
- Use case: "Show me all expenses at McDonald's"

### 2. **SummaryCard**
- Single stat card with title, value, subtitle
- Use case: "How much did I spend at Starbucks?"

### 3. **BarChart**
- Bar chart comparing values across categories
- Use case: "Compare my spending by category"

### 4. **LineChart** (stretch)
- Spending over time
- Use case: "Show my spending trend this month"

### 5. **PieChart** (stretch)
- Category breakdown
- Use case: "What percentage of spending is food?"

### 6. **MetricGrid**
- Multiple summary stats in a grid
- Use case: "Give me an overview of my spending"

## LLM Response Schema

The LLM returns structured JSON matching this schema:

```json
{
  "title": "McDonald's Expenses",
  "components": [
    {
      "type": "summary_card",
      "data": {
        "title": "Total Spent",
        "value": "$21.49",
        "subtitle": "2 transactions"
      }
    },
    {
      "type": "transaction_table",
      "data": {
        "columns": ["Date", "Amount", "Notes"],
        "rows": [
          ["Jan 5, 2026", "$12.50", "Lunch"],
          ["Jan 12, 2026", "$8.99", "Drive-through"]
        ]
      }
    }
  ],
  "spoken_summary": "You spent $21.49 at McDonald's across 2 transactions."
}
```

The LLM can compose multiple components in a single response (e.g., a summary card + a table).

## System Prompt Strategy

The LLM system prompt will:
1. Receive the full CSV data (small enough to fit in context)
2. Know the available component types and their schemas
3. Be instructed to filter/aggregate the data and return JSON only
4. Never return freeform text — always structured UI JSON

## Project Structure

```
generative-ui/
├── PLAN.md
├── TransactionAI/
│   ├── TransactionAI.xcodeproj
│   └── TransactionAI/
│       ├── App/
│       │   └── TransactionAIApp.swift
│       ├── Models/
│       │   ├── Transaction.swift          # CSV row model
│       │   ├── UIResponse.swift           # LLM JSON response model
│       │   └── ComponentType.swift        # Enum of UI component types
│       ├── Services/
│       │   ├── CSVParser.swift            # Parse transactions.csv
│       │   ├── ClaudeService.swift        # Claude API integration
│       │   └── UIResponseParser.swift     # Decode LLM JSON -> models
│       ├── Views/
│       │   ├── ChatView.swift             # Main prompt input + response area
│       │   ├── Components/
│       │   │   ├── ComponentRenderer.swift # Routes component type -> view
│       │   │   ├── TransactionTableView.swift
│       │   │   ├── SummaryCardView.swift
│       │   │   ├── BarChartView.swift
│       │   │   ├── MetricGridView.swift
│       │   │   └── LineChartView.swift    # stretch
│       │   └── PromptInputView.swift
│       └── Resources/
│           └── transactions.csv
└── README.md (optional)
```

## Build Phases

### Phase 1: Foundation
- [ ] Create Xcode project
- [ ] Define `Transaction` model + CSV parser
- [ ] Create sample `transactions.csv` with ~30 rows
- [ ] Build basic `ChatView` with text input

### Phase 2: LLM Integration
- [ ] Define `UIResponse` / `ComponentType` models
- [ ] Build `ClaudeService` (API call with system prompt + CSV context)
- [ ] Craft system prompt with component schemas
- [ ] Parse structured JSON response

### Phase 3: Component Rendering
- [ ] Build `ComponentRenderer` (switch on component type)
- [ ] Implement `SummaryCardView`
- [ ] Implement `TransactionTableView`
- [ ] Implement `BarChartView` (using Swift Charts)
- [ ] Implement `MetricGridView`

### Phase 4: Polish
- [ ] Loading states + animations
- [ ] Error handling (malformed LLM responses)
- [ ] Conversation history (show past queries + generated UIs)
- [ ] Stretch: streaming response rendering

## Key Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| LLM returns invalid JSON | Use Claude's structured output / tool_use to enforce schema |
| LLM hallucinates data | Pass raw CSV in system prompt; instruct to only use provided data |
| Slow response times | Show skeleton loading UI; consider caching common queries |
| CSV too large for context | For prototype, keep to ~100 rows; production would use embeddings/RAG |

## Open Questions
- Should the conversation persist (chat-like) or be single-query?
- API key management — hardcoded for prototype, Keychain for production?
- Support for follow-up queries ("now filter by last month only")?
