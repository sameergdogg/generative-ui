package com.generativeui.dsl

import com.generativeui.dsl.decode.UINodeSerializer
import com.generativeui.dsl.model.UINode
import com.generativeui.dsl.model.UIResponse
import com.generativeui.dsl.snapshot.RenderSnapshot
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.*
import org.junit.Test
import java.io.File

class CrossPlatformParityTest {

    private val json = Json { ignoreUnknownKeys = false }

    private val repoRoot: File by lazy {
        val moduleDir = File(System.getProperty("user.dir"))
        moduleDir.parentFile.parentFile
    }

    private fun loadFixture(name: String): String {
        val f = File(repoRoot, "spec/test-fixtures/$name")
        require(f.exists()) { "Fixture not found: ${f.absolutePath}" }
        return f.readText()
    }

    private fun decodeNode(jsonStr: String): UINode {
        return UINodeSerializer.decodeNode(json.parseToJsonElement(jsonStr).jsonObject)
    }

    private fun decodeResponse(jsonStr: String): UIResponse {
        return json.decodeFromString<UIResponse>(jsonStr)
    }

    private fun snapshotDir(): File {
        return File(repoRoot, "spec/test-snapshots").also { it.mkdirs() }
    }

    private fun assertSnapshotMatches(name: String, snapshot: String) {
        val goldenFile = File(snapshotDir(), "$name.txt")
        if (!goldenFile.exists()) {
            goldenFile.writeText(snapshot)
            println("  [CREATED] Golden snapshot: ${goldenFile.name}")
            return
        }
        val golden = goldenFile.readText()
        assertEquals(
            "Snapshot mismatch for $name.\nGolden file: ${goldenFile.absolutePath}\n",
            golden,
            snapshot
        )
    }

    @Test fun `snapshot - real_claude_response`() {
        val response = decodeResponse(loadFixture("real_claude_response.json"))
        assertSnapshotMatches("real_claude_response", RenderSnapshot.generate(response.layout))
    }

    @Test fun `snapshot - cross_platform_smoke`() {
        val response = decodeResponse(loadFixture("cross_platform_smoke.json"))
        assertSnapshotMatches("cross_platform_smoke", RenderSnapshot.generate(response.layout))
    }

    @Test fun `snapshot - financial_dashboard`() {
        val response = decodeResponse(loadFixture("financial_dashboard.json"))
        assertSnapshotMatches("financial_dashboard", RenderSnapshot.generate(response.layout))
    }

    @Test fun `snapshot - grocery_breakdown`() {
        val response = decodeResponse(loadFixture("grocery_breakdown.json"))
        assertSnapshotMatches("grocery_breakdown", RenderSnapshot.generate(response.layout))
    }

    @Test fun `snapshot - budget_status`() {
        val response = decodeResponse(loadFixture("budget_status.json"))
        assertSnapshotMatches("budget_status", RenderSnapshot.generate(response.layout))
    }

    @Test fun `snapshot - subscription_tracker`() {
        val response = decodeResponse(loadFixture("subscription_tracker.json"))
        assertSnapshotMatches("subscription_tracker", RenderSnapshot.generate(response.layout))
    }

    @Test fun `snapshot - weekly_spending_trend`() {
        val response = decodeResponse(loadFixture("weekly_spending_trend.json"))
        assertSnapshotMatches("weekly_spending_trend", RenderSnapshot.generate(response.layout))
    }

    @Test fun `snapshot - nested_vstack`() {
        assertSnapshotMatches("nested_vstack", RenderSnapshot.generate(decodeNode(loadFixture("nested_vstack.json"))))
    }

    @Test fun `snapshot - card_with_children`() {
        assertSnapshotMatches("card_with_children", RenderSnapshot.generate(decodeNode(loadFixture("card_with_children.json"))))
    }

    @Test fun `snapshot - chart_bar`() {
        assertSnapshotMatches("chart_bar", RenderSnapshot.generate(decodeNode(loadFixture("chart_bar.json"))))
    }

    @Test fun `snapshot - chart_pie`() {
        assertSnapshotMatches("chart_pie", RenderSnapshot.generate(decodeNode(loadFixture("chart_pie.json"))))
    }

    @Test fun `snapshot - all_optionals_missing`() {
        val response = decodeResponse(loadFixture("all_optionals_missing.json"))
        assertSnapshotMatches("all_optionals_missing", RenderSnapshot.generate(response.layout))
    }

    @Test fun `hstack children get equal weight`() {
        val jsonStr = """{"type":"hstack","spacing":10,"children":[
            {"type":"stat","label":"A","value":"1","size":"large"},
            {"type":"stat","label":"B","value":"2","size":"large"},
            {"type":"stat","label":"C","value":"3","size":"large"}
        ]}"""
        val snapshot = RenderSnapshot.generate(decodeNode(jsonStr))
        assertTrue(snapshot.contains("fillsWidth=true"))
        assertEquals(3, snapshot.lines().count { it.contains("weighted=true") })
    }

    @Test fun `standalone stat fills width`() {
        val snapshot = RenderSnapshot.generate(decodeNode("""{"type":"stat","label":"Total","value":"$100","size":"large"}"""))
        assertTrue(snapshot.contains("fillsWidth=true"))
        assertFalse(snapshot.contains("weighted=true"))
    }

    @Test fun `card fills width`() {
        val snapshot = RenderSnapshot.generate(decodeNode("""{"type":"card","child":{"type":"text","content":"Hello"}}"""))
        assertTrue(snapshot.contains("fillsWidth=true"))
    }

    @Test fun `spacer in hstack is weighted`() {
        val snapshot = RenderSnapshot.generate(decodeNode("""{"type":"hstack","children":[{"type":"text","content":"Left"},{"type":"spacer"},{"type":"text","content":"Right"}]}"""))
        assertTrue(snapshot.contains("Spacer(weighted=true)"))
    }

    @Test fun `financial dashboard hstack stats all weighted`() {
        val response = decodeResponse(loadFixture("financial_dashboard.json"))
        val snapshot = RenderSnapshot.generate(response.layout)
        val lines = snapshot.lines()
        val hstackLine = lines.indexOfFirst { it.contains("HStack") && it.contains("spacing=10.0") }
        assertTrue(hstackLine >= 0)
        val statLines = lines.subList(hstackLine + 1, minOf(hstackLine + 4, lines.size))
        assertEquals(3, statLines.count { it.contains("Stat(") })
        assertEquals(3, statLines.count { it.contains("weighted=true") })
    }

    @Test fun `all fixtures decode without errors`() {
        val fixtures = listOf(
            "simple_text.json", "simple_stat.json", "nested_vstack.json",
            "card_with_children.json", "deep_nesting.json", "chart_bar.json",
            "chart_pie.json", "all_optionals_missing.json", "unknown_type.json",
            "real_claude_response.json", "cross_platform_smoke.json",
            "financial_dashboard.json", "grocery_breakdown.json",
            "budget_status.json", "subscription_tracker.json",
            "weekly_spending_trend.json"
        )
        val errors = mutableListOf<String>()
        fixtures.forEach { name ->
            try {
                val content = loadFixture(name)
                try { decodeResponse(content) } catch (_: Exception) { decodeNode(content) }
            } catch (e: Exception) {
                errors.add("$name: ${e.message}")
            }
        }
        assertTrue("Fixtures with decode errors: $errors", errors.isEmpty())
    }

    @Test fun `node counts match expected`() {
        val expected = mapOf(
            "deep_nesting.json" to 11,
            "nested_vstack.json" to 4,
            "card_with_children.json" to 5,
        )
        expected.forEach { (fixture, count) ->
            val node = decodeNode(loadFixture(fixture))
            assertEquals("Node count mismatch for $fixture", count, nodeCount(node))
        }
    }

    private fun nodeCount(node: UINode): Int = when (node) {
        is UINode.VStack -> 1 + node.children.sumOf { nodeCount(it) }
        is UINode.HStack -> 1 + node.children.sumOf { nodeCount(it) }
        is UINode.ZStack -> 1 + node.children.sumOf { nodeCount(it) }
        is UINode.Card -> 1 + nodeCount(node.child)
        is UINode.ListNode -> 1 + node.items.sumOf { nodeCount(it) }
        else -> 1
    }
}
