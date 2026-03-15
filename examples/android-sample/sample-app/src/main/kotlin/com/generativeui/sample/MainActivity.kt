package com.generativeui.sample

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.generativeui.dsl.decode.UINodeSerializer
import com.generativeui.dsl.model.UIResponse
import com.generativeui.dsl.render.NodeRenderer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject

/**
 * Demo app that renders hardcoded JSON fixtures using the Generative UI DSL.
 * No Claude API needed — proves that the same JSON renders natively on Android.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                DemoScreen()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DemoScreen() {
    var selectedTab by remember { mutableIntStateOf(0) }
    val tabs = listOf("Claude Response", "Financial Dashboard", "Grocery", "Weekly Spending", "Subscriptions", "Budget Status", "Smoke Test", "Minimal")

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Generative UI DSL") })
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding)) {
            ScrollableTabRow(selectedTabIndex = selectedTab, edgePadding = 8.dp) {
                tabs.forEachIndexed { index, title ->
                    Tab(
                        selected = selectedTab == index,
                        onClick = { selectedTab = index },
                        text = { Text(title) }
                    )
                }
            }

            val jsonStr = when (selectedTab) {
                0 -> REAL_CLAUDE_RESPONSE
                1 -> FINANCIAL_DASHBOARD
                2 -> GROCERY_BREAKDOWN
                3 -> WEEKLY_SPENDING_TREND
                4 -> SUBSCRIPTION_TRACKER
                5 -> BUDGET_STATUS
                6 -> CROSS_PLATFORM_SMOKE
                7 -> MINIMAL_RESPONSE
                else -> REAL_CLAUDE_RESPONSE
            }

            val json = Json { ignoreUnknownKeys = false }
            val response = remember(jsonStr) {
                json.decodeFromString<UIResponse>(jsonStr)
            }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = response.title,
                    style = MaterialTheme.typography.headlineMedium
                )
                @Suppress("DEPRECATION") Divider()
                NodeRenderer(node = response.layout)
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = response.spokenSummary,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

// -- Hardcoded JSON fixtures (same ones that render on iOS) --

private val REAL_CLAUDE_RESPONSE = """
{
  "title": "McDonald's Spending Summary",
  "layout": {
    "type": "vstack",
    "spacing": 16,
    "alignment": "leading",
    "children": [
      {
        "type": "hstack",
        "spacing": 12,
        "children": [
          {"type": "stat", "label": "Total Spent", "value": "${'$'}21", "color": "red", "size": "large", "icon": "dollarsign.circle"},
          {"type": "stat", "label": "Transactions", "value": "2", "size": "large", "icon": "list.bullet"}
        ]
      },
      {"type": "divider"},
      {
        "type": "card",
        "color": "orange",
        "padding": 12,
        "child": {
          "type": "vstack",
          "spacing": 8,
          "alignment": "leading",
          "children": [
            {
              "type": "hstack",
              "children": [
                {"type": "image", "system_name": "fork.knife", "color": "orange"},
                {"type": "text", "content": "McDonald's Visits", "style": "headline", "weight": "semibold"}
              ]
            },
            {
              "type": "list",
              "items": [
                {
                  "type": "hstack",
                  "children": [
                    {"type": "text", "content": "Jan 5, 2026", "style": "body", "color": "secondary"},
                    {"type": "spacer"},
                    {"type": "text", "content": "Lunch", "style": "caption", "color": "secondary"},
                    {"type": "spacer"},
                    {"type": "text", "content": "${'$'}13", "style": "body", "weight": "semibold", "color": "red"}
                  ]
                },
                {
                  "type": "hstack",
                  "children": [
                    {"type": "text", "content": "Jan 12, 2026", "style": "body", "color": "secondary"},
                    {"type": "spacer"},
                    {"type": "text", "content": "Drive-through", "style": "caption", "color": "secondary"},
                    {"type": "spacer"},
                    {"type": "text", "content": "${'$'}9", "style": "body", "weight": "semibold", "color": "red"}
                  ]
                }
              ]
            }
          ]
        }
      },
      {"type": "badge", "text": "Food & Dining", "color": "orange"}
    ]
  },
  "spoken_summary": "You spent ${'$'}21 at McDonald's across 2 transactions in January 2026."
}
""".trimIndent()

private val CROSS_PLATFORM_SMOKE = """
{
  "title": "Cross-Platform Smoke Test",
  "layout": {
    "type": "vstack",
    "spacing": 12,
    "alignment": "leading",
    "children": [
      {"type": "text", "content": "Cross-Platform DSL Demo", "style": "largeTitle", "weight": "bold", "color": "primary"},
      {
        "type": "hstack",
        "spacing": 8,
        "alignment": "center",
        "children": [
          {"type": "image", "system_name": "dollarsign.circle", "color": "green", "size": "large"},
          {"type": "stat", "label": "Total Balance", "value": "${'$'}12,450", "color": "green", "size": "large", "icon": "dollarsign.circle"},
          {"type": "stat", "label": "Transactions", "value": "47", "size": "large", "icon": "list.bullet"}
        ]
      },
      {"type": "divider"},
      {
        "type": "card",
        "color": "blue",
        "padding": 16,
        "cornerRadius": 12,
        "child": {
          "type": "vstack",
          "spacing": 8,
          "alignment": "leading",
          "children": [
            {"type": "text", "content": "Monthly Spending", "style": "headline", "weight": "semibold"},
            {"type": "progress", "value": 750, "total": 1000, "label": "Budget Used", "color": "blue"},
            {"type": "badge", "text": "On Track", "color": "green"}
          ]
        }
      },
      {
        "type": "chart",
        "variant": "bar",
        "title": "Spending by Category",
        "data": [
          {"label": "Food", "value": 320.5, "color": "orange"},
          {"label": "Transport", "value": 150.0, "color": "blue"},
          {"label": "Shopping", "value": 280.75, "color": "purple"}
        ]
      },
      {
        "type": "table",
        "title": "Recent Transactions",
        "headers": ["Date", "Merchant", "Amount"],
        "rows": [
          ["Mar 10", "Starbucks", "${'$'}7.50"],
          ["Mar 9", "Amazon", "${'$'}45.99"],
          ["Mar 8", "Shell Gas", "${'$'}52.00"]
        ]
      },
      {
        "type": "list",
        "items": [
          {
            "type": "hstack",
            "children": [
              {"type": "image", "system_name": "fork.knife", "color": "orange"},
              {"type": "text", "content": "Restaurant spending up 15%", "style": "body"},
              {"type": "spacer"},
              {"type": "badge", "text": "+15%", "color": "red"}
            ]
          },
          {
            "type": "hstack",
            "children": [
              {"type": "image", "system_name": "cart.fill", "color": "purple"},
              {"type": "text", "content": "Shopping within budget", "style": "body"},
              {"type": "spacer"},
              {"type": "badge", "text": "OK", "color": "green"}
            ]
          }
        ]
      },
      {
        "type": "zstack",
        "children": [
          {"type": "text", "content": "Layered background", "style": "caption", "color": "secondary"},
          {"type": "text", "content": "Layered foreground", "style": "caption", "color": "primary"}
        ]
      },
      {"type": "spacer"},
      {"type": "text", "content": "All node types exercised successfully.", "style": "footnote", "color": "secondary"}
    ]
  },
  "spoken_summary": "Cross-platform smoke test showing all 14 node types."
}
""".trimIndent()

private val MINIMAL_RESPONSE = """
{
  "title": "Minimal Response",
  "layout": {
    "type": "vstack",
    "children": [
      {"type": "text", "content": "Just text"},
      {"type": "stat", "label": "Count", "value": "5"},
      {"type": "image", "system_name": "star"},
      {"type": "badge", "text": "Tag"},
      {"type": "progress", "value": 0.5},
      {"type": "divider"},
      {"type": "spacer"}
    ]
  },
  "spoken_summary": "Minimal test"
}
""".trimIndent()

private val FINANCIAL_DASHBOARD = """
{
  "title": "January Financial Dashboard",
  "layout": {
    "type": "vstack",
    "spacing": 16,
    "alignment": "leading",
    "children": [
      {
        "type": "hstack",
        "spacing": 10,
        "children": [
          {"type": "stat", "label": "Income", "value": "${'$'}8,450", "color": "green", "size": "large", "icon": "arrow.up.right"},
          {"type": "stat", "label": "Expenses", "value": "${'$'}5,230", "color": "red", "size": "large", "icon": "arrow.down.right"},
          {"type": "stat", "label": "Saved", "value": "${'$'}3,220", "color": "blue", "size": "large", "icon": "dollarsign.circle"}
        ]
      },
      {
        "type": "card",
        "color": "green",
        "padding": 14,
        "child": {
          "type": "vstack",
          "spacing": 8,
          "alignment": "leading",
          "children": [
            {"type": "text", "content": "Savings Goal: Vacation Fund", "style": "headline", "weight": "semibold"},
            {"type": "progress", "value": 3220, "total": 5000, "label": "Progress", "color": "green"},
            {
              "type": "hstack",
              "children": [
                {"type": "badge", "text": "${'$'}3,220 saved", "color": "green"},
                {"type": "spacer"},
                {"type": "text", "content": "${'$'}1,780 to go", "style": "caption", "color": "secondary"}
              ]
            }
          ]
        }
      },
      {
        "type": "chart",
        "variant": "bar",
        "title": "Spending by Category",
        "data": [
          {"label": "Housing", "value": 1800, "color": "blue"},
          {"label": "Food", "value": 920, "color": "orange"},
          {"label": "Transport", "value": 540, "color": "purple"},
          {"label": "Shopping", "value": 680, "color": "pink"},
          {"label": "Health", "value": 290, "color": "green"},
          {"label": "Other", "value": 1000, "color": "gray"}
        ]
      }
    ]
  },
  "spoken_summary": "In January you earned ${'$'}8,450, spent ${'$'}5,230, and saved ${'$'}3,220 toward your vacation fund."
}
""".trimIndent()

private val GROCERY_BREAKDOWN = """
{
  "title": "Grocery Spending Breakdown",
  "layout": {
    "type": "vstack",
    "spacing": 14,
    "alignment": "leading",
    "children": [
      {
        "type": "hstack",
        "spacing": 10,
        "children": [
          {"type": "image", "system_name": "cart.fill", "color": "green", "size": "large"},
          {
            "type": "vstack",
            "spacing": 2,
            "alignment": "leading",
            "children": [
              {"type": "text", "content": "Total Grocery Spend", "style": "subheadline", "color": "secondary"},
              {"type": "text", "content": "${'$'}847.32", "style": "title", "weight": "bold", "color": "green"}
            ]
          }
        ]
      },
      {"type": "divider"},
      {
        "type": "chart",
        "variant": "pie",
        "title": "By Store",
        "data": [
          {"label": "Whole Foods", "value": 342.10, "color": "green"},
          {"label": "Trader Joe's", "value": 218.50, "color": "orange"},
          {"label": "Costco", "value": 186.72, "color": "blue"},
          {"label": "Target", "value": 100.00, "color": "red"}
        ]
      },
      {
        "type": "table",
        "title": "Top Purchases",
        "headers": ["Item", "Store", "Price"],
        "rows": [
          ["Organic Salmon", "Whole Foods", "${'$'}24.99"],
          ["Olive Oil (2L)", "Costco", "${'$'}18.49"],
          ["Almond Milk x6", "Trader Joe's", "${'$'}15.94"],
          ["Avocados (bag)", "Costco", "${'$'}9.99"],
          ["Sourdough Bread", "Whole Foods", "${'$'}7.50"]
        ]
      },
      {
        "type": "card",
        "color": "orange",
        "padding": 12,
        "child": {
          "type": "hstack",
          "children": [
            {"type": "image", "system_name": "exclamationmark.triangle", "color": "orange"},
            {"type": "text", "content": "Grocery spending is 12% over your ${'$'}750 monthly budget", "style": "subheadline", "weight": "medium"}
          ]
        }
      }
    ]
  },
  "spoken_summary": "You spent ${'$'}847.32 on groceries this month across 4 stores, which is 12% over your ${'$'}750 budget."
}
""".trimIndent()

private val WEEKLY_SPENDING_TREND = """
{
  "title": "This Week's Spending",
  "layout": {
    "type": "vstack",
    "spacing": 14,
    "alignment": "leading",
    "children": [
      {
        "type": "hstack",
        "spacing": 10,
        "children": [
          {"type": "stat", "label": "This Week", "value": "${'$'}612", "color": "blue", "size": "large", "icon": "calendar"},
          {"type": "stat", "label": "Daily Avg", "value": "${'$'}87", "color": "purple", "size": "large", "icon": "clock"}
        ]
      },
      {
        "type": "chart",
        "variant": "line",
        "title": "Daily Spending",
        "data": [
          {"label": "Mon", "value": 45.20, "color": "blue"},
          {"label": "Tue", "value": 132.50, "color": "blue"},
          {"label": "Wed", "value": 28.00, "color": "blue"},
          {"label": "Thu", "value": 215.80, "color": "red"},
          {"label": "Fri", "value": 89.30, "color": "blue"},
          {"label": "Sat", "value": 67.40, "color": "blue"},
          {"label": "Sun", "value": 33.80, "color": "blue"}
        ]
      },
      {"type": "divider"},
      {
        "type": "text",
        "content": "Notable Transactions",
        "style": "headline",
        "weight": "semibold"
      },
      {
        "type": "list",
        "items": [
          {
            "type": "hstack",
            "children": [
              {"type": "image", "system_name": "fuelpump.fill", "color": "blue"},
              {
                "type": "vstack",
                "spacing": 2,
                "alignment": "leading",
                "children": [
                  {"type": "text", "content": "Shell Gas Station", "style": "body", "weight": "medium"},
                  {"type": "text", "content": "Thursday", "style": "caption", "color": "secondary"}
                ]
              },
              {"type": "spacer"},
              {"type": "text", "content": "${'$'}68.40", "style": "body", "weight": "semibold"}
            ]
          },
          {
            "type": "hstack",
            "children": [
              {"type": "image", "system_name": "fork.knife", "color": "orange"},
              {
                "type": "vstack",
                "spacing": 2,
                "alignment": "leading",
                "children": [
                  {"type": "text", "content": "The Cheesecake Factory", "style": "body", "weight": "medium"},
                  {"type": "text", "content": "Thursday", "style": "caption", "color": "secondary"}
                ]
              },
              {"type": "spacer"},
              {"type": "text", "content": "${'$'}94.50", "style": "body", "weight": "semibold"}
            ]
          },
          {
            "type": "hstack",
            "children": [
              {"type": "image", "system_name": "cart.fill", "color": "green"},
              {
                "type": "vstack",
                "spacing": 2,
                "alignment": "leading",
                "children": [
                  {"type": "text", "content": "Whole Foods Market", "style": "body", "weight": "medium"},
                  {"type": "text", "content": "Tuesday", "style": "caption", "color": "secondary"}
                ]
              },
              {"type": "spacer"},
              {"type": "text", "content": "${'$'}86.20", "style": "body", "weight": "semibold"}
            ]
          }
        ]
      },
      {
        "type": "hstack",
        "children": [
          {"type": "badge", "text": "Thu was highest", "color": "red"},
          {"type": "badge", "text": "Wed was lowest", "color": "green"}
        ]
      }
    ]
  },
  "spoken_summary": "You spent ${'$'}612 this week with a daily average of ${'$'}87. Thursday was your highest spending day at ${'$'}215.80."
}
""".trimIndent()

private val SUBSCRIPTION_TRACKER = """
{
  "title": "Active Subscriptions",
  "layout": {
    "type": "vstack",
    "spacing": 14,
    "alignment": "leading",
    "children": [
      {
        "type": "hstack",
        "spacing": 10,
        "children": [
          {"type": "stat", "label": "Monthly Total", "value": "${'$'}94.86", "color": "purple", "size": "large", "icon": "creditcard"},
          {"type": "stat", "label": "Services", "value": "7", "size": "large", "icon": "list.bullet"}
        ]
      },
      {
        "type": "chart",
        "variant": "pie",
        "title": "Cost Breakdown",
        "data": [
          {"label": "Streaming", "value": 42.97, "color": "red"},
          {"label": "Cloud", "value": 12.99, "color": "blue"},
          {"label": "Music", "value": 10.99, "color": "pink"},
          {"label": "Fitness", "value": 14.99, "color": "green"},
          {"label": "News", "value": 12.92, "color": "orange"}
        ]
      },
      {"type": "divider"},
      {
        "type": "list",
        "items": [
          {
            "type": "hstack",
            "children": [
              {"type": "image", "system_name": "play.rectangle.fill", "color": "red"},
              {
                "type": "vstack",
                "spacing": 2,
                "alignment": "leading",
                "children": [
                  {"type": "text", "content": "Netflix Premium", "style": "body", "weight": "medium"},
                  {"type": "text", "content": "Renews Mar 22", "style": "caption", "color": "secondary"}
                ]
              },
              {"type": "spacer"},
              {"type": "text", "content": "${'$'}22.99", "style": "body", "weight": "semibold"}
            ]
          },
          {
            "type": "hstack",
            "children": [
              {"type": "image", "system_name": "cloud.fill", "color": "blue"},
              {
                "type": "vstack",
                "spacing": 2,
                "alignment": "leading",
                "children": [
                  {"type": "text", "content": "iCloud+ 2TB", "style": "body", "weight": "medium"},
                  {"type": "text", "content": "Renews Mar 15", "style": "caption", "color": "secondary"}
                ]
              },
              {"type": "spacer"},
              {"type": "text", "content": "${'$'}12.99", "style": "body", "weight": "semibold"}
            ]
          },
          {
            "type": "hstack",
            "children": [
              {"type": "image", "system_name": "music.note", "color": "pink"},
              {
                "type": "vstack",
                "spacing": 2,
                "alignment": "leading",
                "children": [
                  {"type": "text", "content": "Spotify Family", "style": "body", "weight": "medium"},
                  {"type": "text", "content": "Renews Mar 28", "style": "caption", "color": "secondary"}
                ]
              },
              {"type": "spacer"},
              {"type": "text", "content": "${'$'}16.99", "style": "body", "weight": "semibold"}
            ]
          },
          {
            "type": "hstack",
            "children": [
              {"type": "image", "system_name": "figure.run", "color": "green"},
              {
                "type": "vstack",
                "spacing": 2,
                "alignment": "leading",
                "children": [
                  {"type": "text", "content": "Peloton Digital", "style": "body", "weight": "medium"},
                  {"type": "text", "content": "Renews Apr 1", "style": "caption", "color": "secondary"}
                ]
              },
              {"type": "spacer"},
              {"type": "text", "content": "${'$'}14.99", "style": "body", "weight": "semibold"}
            ]
          }
        ]
      },
      {
        "type": "card",
        "color": "purple",
        "padding": 12,
        "child": {
          "type": "hstack",
          "children": [
            {"type": "image", "system_name": "info.circle", "color": "purple"},
            {"type": "text", "content": "You're spending ${'$'}1,138/year on subscriptions", "style": "subheadline", "weight": "medium"}
          ]
        }
      }
    ]
  },
  "spoken_summary": "You have 7 active subscriptions totaling ${'$'}94.86 per month, or about ${'$'}1,138 per year."
}
""".trimIndent()

private val BUDGET_STATUS = """
{
  "title": "March Budget Status",
  "layout": {
    "type": "vstack",
    "spacing": 14,
    "alignment": "leading",
    "children": [
      {
        "type": "card",
        "color": "blue",
        "padding": 16,
        "child": {
          "type": "vstack",
          "spacing": 10,
          "alignment": "leading",
          "children": [
            {
              "type": "hstack",
              "children": [
                {"type": "text", "content": "Overall Budget", "style": "headline", "weight": "bold"},
                {"type": "spacer"},
                {"type": "badge", "text": "13 days left", "color": "blue"}
              ]
            },
            {"type": "progress", "value": 3180, "total": 5000, "label": "Spent ${'$'}3,180 of ${'$'}5,000", "color": "blue"},
            {"type": "text", "content": "${'$'}1,820 remaining", "style": "title2", "weight": "bold", "color": "green"}
          ]
        }
      },
      {
        "type": "text",
        "content": "Category Budgets",
        "style": "headline",
        "weight": "semibold"
      },
      {
        "type": "card",
        "padding": 12,
        "child": {
          "type": "vstack",
          "spacing": 12,
          "alignment": "leading",
          "children": [
            {
              "type": "vstack",
              "spacing": 4,
              "alignment": "leading",
              "children": [
                {
                  "type": "hstack",
                  "children": [
                    {"type": "image", "system_name": "house.fill", "color": "blue"},
                    {"type": "text", "content": "Housing", "style": "body", "weight": "medium"},
                    {"type": "spacer"},
                    {"type": "text", "content": "${'$'}1,800 / ${'$'}1,800", "style": "caption", "color": "secondary"}
                  ]
                },
                {"type": "progress", "value": 1800, "total": 1800, "color": "blue"}
              ]
            },
            {
              "type": "vstack",
              "spacing": 4,
              "alignment": "leading",
              "children": [
                {
                  "type": "hstack",
                  "children": [
                    {"type": "image", "system_name": "fork.knife", "color": "orange"},
                    {"type": "text", "content": "Food & Dining", "style": "body", "weight": "medium"},
                    {"type": "spacer"},
                    {"type": "text", "content": "${'$'}620 / ${'$'}800", "style": "caption", "color": "secondary"}
                  ]
                },
                {"type": "progress", "value": 620, "total": 800, "color": "orange"}
              ]
            },
            {
              "type": "vstack",
              "spacing": 4,
              "alignment": "leading",
              "children": [
                {
                  "type": "hstack",
                  "children": [
                    {"type": "image", "system_name": "car.fill", "color": "purple"},
                    {"type": "text", "content": "Transport", "style": "body", "weight": "medium"},
                    {"type": "spacer"},
                    {"type": "text", "content": "${'$'}380 / ${'$'}400", "style": "caption", "color": "secondary"}
                  ]
                },
                {"type": "progress", "value": 380, "total": 400, "color": "purple"}
              ]
            },
            {
              "type": "vstack",
              "spacing": 4,
              "alignment": "leading",
              "children": [
                {
                  "type": "hstack",
                  "children": [
                    {"type": "image", "system_name": "cart.fill", "color": "pink"},
                    {"type": "text", "content": "Shopping", "style": "body", "weight": "medium"},
                    {"type": "spacer"},
                    {"type": "text", "content": "${'$'}280 / ${'$'}500", "style": "caption", "color": "secondary"}
                  ]
                },
                {"type": "progress", "value": 280, "total": 500, "color": "pink"}
              ]
            },
            {
              "type": "vstack",
              "spacing": 4,
              "alignment": "leading",
              "children": [
                {
                  "type": "hstack",
                  "children": [
                    {"type": "image", "system_name": "heart.fill", "color": "green"},
                    {"type": "text", "content": "Health & Fitness", "style": "body", "weight": "medium"},
                    {"type": "spacer"},
                    {"type": "text", "content": "${'$'}100 / ${'$'}300", "style": "caption", "color": "secondary"}
                  ]
                },
                {"type": "progress", "value": 100, "total": 300, "color": "green"}
              ]
            }
          ]
        }
      },
      {
        "type": "hstack",
        "children": [
          {"type": "badge", "text": "Housing: at limit", "color": "red"},
          {"type": "badge", "text": "Transport: 95%", "color": "orange"},
          {"type": "badge", "text": "Shopping: on track", "color": "green"}
        ]
      }
    ]
  },
  "spoken_summary": "You've spent ${'$'}3,180 of your ${'$'}5,000 March budget with 13 days remaining. Housing is at its limit and transport is at 95%."
}
""".trimIndent()
