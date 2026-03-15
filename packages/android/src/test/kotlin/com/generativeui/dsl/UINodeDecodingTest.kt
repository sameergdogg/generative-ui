package com.generativeui.dsl

import com.generativeui.dsl.decode.UINodeSerializer
import com.generativeui.dsl.model.UINode
import com.generativeui.dsl.model.UIResponse
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.*
import org.junit.Test
import java.io.File

class UINodeDecodingTest {

    private val json = Json { ignoreUnknownKeys = false }

    private fun loadFixture(name: String): String {
        val moduleDir = File(System.getProperty("user.dir"))
        val repoRoot = moduleDir.parentFile.parentFile
        val fixtureFile = File(repoRoot, "spec/test-fixtures/$name")
        require(fixtureFile.exists()) {
            "Fixture not found: ${fixtureFile.absolutePath} (user.dir=${moduleDir.absolutePath})"
        }
        return fixtureFile.readText()
    }

    private fun decodeNode(jsonStr: String): UINode {
        val element = json.parseToJsonElement(jsonStr).jsonObject
        return UINodeSerializer.decodeNode(element)
    }

    private fun decodeResponse(jsonStr: String): UIResponse {
        return json.decodeFromString<UIResponse>(jsonStr)
    }

    @Test
    fun `decode simple text`() {
        val node = decodeNode(loadFixture("simple_text.json"))
        assertTrue(node is UINode.Text)
        val t = node as UINode.Text
        assertEquals("Hello World", t.content)
        assertEquals("title", t.style)
        assertEquals("blue", t.color)
        assertEquals("bold", t.weight)
    }

    @Test
    fun `decode text minimum fields`() {
        val node = decodeNode("""{"type":"text","content":"Hi"}""")
        assertTrue(node is UINode.Text)
        val t = node as UINode.Text
        assertEquals("Hi", t.content)
        assertNull(t.style)
        assertNull(t.color)
        assertNull(t.weight)
        assertNull(t.maxLines)
    }

    @Test
    fun `decode text with maxLines`() {
        val node = decodeNode("""{"type":"text","content":"Truncated","maxLines":2}""")
        assertTrue(node is UINode.Text)
        assertEquals(2, (node as UINode.Text).maxLines)
    }

    @Test
    fun `decode simple stat`() {
        val node = decodeNode(loadFixture("simple_stat.json"))
        assertTrue(node is UINode.Stat)
        val s = node as UINode.Stat
        assertEquals("Total Spent", s.label)
        assertEquals("\$491", s.value)
        assertEquals("red", s.color)
        assertEquals("large", s.size)
        assertEquals("dollarsign.circle", s.icon)
    }

    @Test
    fun `decode stat minimum fields`() {
        val node = decodeNode("""{"type":"stat","label":"Count","value":"5"}""")
        assertTrue(node is UINode.Stat)
        val s = node as UINode.Stat
        assertNull(s.color)
        assertNull(s.size)
        assertNull(s.icon)
    }

    @Test
    fun `decode image node`() {
        val node = decodeNode("""{"type":"image","system_name":"cart.fill","color":"blue","size":"large"}""")
        assertTrue(node is UINode.Image)
        val img = node as UINode.Image
        assertEquals("cart.fill", img.systemName)
        assertEquals("blue", img.color)
        assertEquals("large", img.size)
    }

    @Test
    fun `decode image minimum fields`() {
        val node = decodeNode("""{"type":"image","system_name":"star"}""")
        assertTrue(node is UINode.Image)
        assertNull((node as UINode.Image).color)
        assertNull(node.size)
    }

    @Test
    fun `decode badge node`() {
        val node = decodeNode("""{"type":"badge","text":"Food & Dining","color":"orange"}""")
        assertTrue(node is UINode.Badge)
        assertEquals("Food & Dining", (node as UINode.Badge).text)
        assertEquals("orange", node.color)
    }

    @Test
    fun `decode badge no color`() {
        val node = decodeNode("""{"type":"badge","text":"Tag"}""")
        assertTrue(node is UINode.Badge)
        assertNull((node as UINode.Badge).color)
    }

    @Test
    fun `decode divider`() {
        val node = decodeNode("""{"type":"divider"}""")
        assertTrue(node is UINode.Divider)
    }

    @Test
    fun `decode spacer`() {
        val node = decodeNode("""{"type":"spacer"}""")
        assertTrue(node is UINode.Spacer)
    }

    @Test
    fun `decode progress node`() {
        val node = decodeNode("""{"type":"progress","value":75,"total":100,"label":"Budget Used","color":"green"}""")
        assertTrue(node is UINode.Progress)
        val p = node as UINode.Progress
        assertEquals(75.0, p.value, 0.01)
        assertEquals(100.0, p.total, 0.01)
        assertEquals("Budget Used", p.label)
        assertEquals("green", p.color)
    }

    @Test
    fun `decode progress default total`() {
        val node = decodeNode("""{"type":"progress","value":0.5}""")
        assertTrue(node is UINode.Progress)
        assertEquals(1.0, (node as UINode.Progress).total, 0.01)
    }

    @Test
    fun `decode table node`() {
        val node = decodeNode("""{"type":"table","title":"Transactions","headers":["Date","Merchant","Amount"],"rows":[["Jan 5","McDonald's","${'$'}13"],["Jan 7","Starbucks","${'$'}7"]]}""")
        assertTrue(node is UINode.Table)
        val t = node as UINode.Table
        assertEquals("Transactions", t.title)
        assertEquals(listOf("Date", "Merchant", "Amount"), t.headers)
        assertEquals(2, t.rows.size)
    }

    @Test
    fun `decode table minimum fields`() {
        val node = decodeNode("""{"type":"table"}""")
        assertTrue(node is UINode.Table)
        val t = node as UINode.Table
        assertNull(t.title)
        assertTrue(t.headers.isEmpty())
        assertTrue(t.rows.isEmpty())
    }

    @Test
    fun `decode chart bar`() {
        val node = decodeNode(loadFixture("chart_bar.json"))
        assertTrue(node is UINode.Chart)
        val c = node as UINode.Chart
        assertEquals("bar", c.variant)
        assertEquals("Spending by Category", c.title)
        assertEquals(3, c.data.size)
        assertEquals("Food", c.data[0].label)
        assertEquals(120.5, c.data[0].value, 0.01)
        assertEquals("orange", c.data[0].color)
    }

    @Test
    fun `decode chart pie`() {
        val node = decodeNode(loadFixture("chart_pie.json"))
        assertTrue(node is UINode.Chart)
        assertEquals("pie", (node as UINode.Chart).variant)
        assertEquals(4, node.data.size)
    }

    @Test
    fun `decode chart line`() {
        val node = decodeNode("""{"type":"chart","variant":"line","title":"Trend","data":[{"label":"W1","value":10},{"label":"W2","value":20},{"label":"W3","value":15}]}""")
        assertTrue(node is UINode.Chart)
        assertEquals("line", (node as UINode.Chart).variant)
        assertEquals(3, node.data.size)
    }

    @Test
    fun `decode nested vstack`() {
        val node = decodeNode(loadFixture("nested_vstack.json"))
        assertTrue(node is UINode.VStack)
        val v = node as UINode.VStack
        assertEquals(3, v.children.size)
        assertEquals(12.0, v.spacing!!, 0.01)
        assertEquals("leading", v.alignment)
        assertTrue(v.children.all { it is UINode.Text })
    }

    @Test
    fun `decode card with children`() {
        val node = decodeNode(loadFixture("card_with_children.json"))
        assertTrue(node is UINode.Card)
        val card = node as UINode.Card
        assertEquals("blue", card.color)
        assertEquals(16.0, card.padding!!, 0.01)
        assertEquals(12.0, card.cornerRadius!!, 0.01)
        assertTrue(card.child is UINode.VStack)
        assertEquals(3, (card.child as UINode.VStack).children.size)
    }

    @Test
    fun `decode deep nesting`() {
        val node = decodeNode(loadFixture("deep_nesting.json"))
        assertEquals(11, nodeCount(node))
    }

    @Test
    fun `unknown type becomes Unknown node`() {
        val node = decodeNode(loadFixture("unknown_type.json"))
        assertTrue(node is UINode.Unknown)
        assertEquals("fancy_widget", (node as UINode.Unknown).typeName)
    }

    @Test
    fun `fault tolerant children skips invalid`() {
        val jsonStr = """{"type":"vstack","children":[
            {"type":"text","content":"Valid 1"},
            {"invalid":"this has no type field"},
            {"type":"text","content":"Valid 2"},
            {"type":"nonexistent_widget","foo":"bar"},
            {"type":"text","content":"Valid 3"}
        ]}"""
        val node = decodeNode(jsonStr)
        assertTrue(node is UINode.VStack)
        val v = node as UINode.VStack
        assertEquals(4, v.children.size)
        assertTrue(v.children[2] is UINode.Unknown)
    }

    @Test
    fun `fault tolerant list skips invalid items`() {
        val jsonStr = """{"type":"list","items":[
            {"type":"text","content":"Good item"},
            {"broken": true},
            {"type":"text","content":"Another good item"}
        ]}"""
        val node = decodeNode(jsonStr)
        assertTrue(node is UINode.ListNode)
        assertEquals(2, (node as UINode.ListNode).items.size)
    }

    @Test
    fun `decode real claude response fixture`() {
        val response = decodeResponse(loadFixture("real_claude_response.json"))
        assertEquals("McDonald's Spending Summary", response.title)
        assertTrue(response.spokenSummary.isNotEmpty())

        val count = nodeCount(response.layout)
        assertTrue("Real response should have substantial node count", count > 10)

        val allNodes = flattenTree(response.layout)
        assertTrue(allNodes.any { it is UINode.Text })
        assertTrue(allNodes.any { it is UINode.Stat })
        assertTrue(allNodes.any { it is UINode.Card })
        assertTrue(allNodes.any { it is UINode.ListNode })
        assertTrue(allNodes.any { it is UINode.Badge })
    }

    @Test
    fun `decode cross platform smoke test`() {
        val response = decodeResponse(loadFixture("cross_platform_smoke.json"))
        assertEquals("Cross-Platform Smoke Test", response.title)

        val allNodes = flattenTree(response.layout)
        assertTrue(allNodes.any { it is UINode.VStack })
        assertTrue(allNodes.any { it is UINode.HStack })
        assertTrue(allNodes.any { it is UINode.ZStack })
        assertTrue(allNodes.any { it is UINode.Text })
        assertTrue(allNodes.any { it is UINode.Stat })
        assertTrue(allNodes.any { it is UINode.Image })
        assertTrue(allNodes.any { it is UINode.Badge })
        assertTrue(allNodes.any { it is UINode.Card })
        assertTrue(allNodes.any { it is UINode.Progress })
        assertTrue(allNodes.any { it is UINode.Chart })
        assertTrue(allNodes.any { it is UINode.ListNode })
        assertTrue(allNodes.any { it is UINode.Table })
        assertTrue(allNodes.any { it is UINode.Divider })
        assertTrue(allNodes.any { it is UINode.Spacer })
    }

    @Test
    fun `decode all optionals missing`() {
        val response = decodeResponse(loadFixture("all_optionals_missing.json"))
        assertEquals("Minimal Response", response.title)
        assertTrue(response.layout is UINode.VStack)
        assertEquals(7, (response.layout as UINode.VStack).children.size)
    }

    @Test
    fun `round trip text`() {
        val original = decodeNode("""{"type":"text","content":"Round trip","style":"headline","color":"red","weight":"bold"}""")
        val encoded = json.encodeToString(UINode.serializer(), original)
        val decoded = decodeNode(encoded)
        assertTrue(decoded is UINode.Text)
        val t = decoded as UINode.Text
        assertEquals("Round trip", t.content)
        assertEquals("headline", t.style)
        assertEquals("red", t.color)
        assertEquals("bold", t.weight)
    }

    @Test
    fun `round trip vstack`() {
        val original = decodeNode("""{"type":"vstack","spacing":10,"alignment":"leading","children":[{"type":"text","content":"A"},{"type":"text","content":"B"}]}""")
        val encoded = json.encodeToString(UINode.serializer(), original)
        val decoded = decodeNode(encoded)
        assertTrue(decoded is UINode.VStack)
        val v = decoded as UINode.VStack
        assertEquals(2, v.children.size)
        assertEquals(10.0, v.spacing!!, 0.01)
        assertEquals("leading", v.alignment)
    }

    @Test
    fun `round trip response`() {
        val jsonStr = """{"title":"Test","layout":{"type":"text","content":"Hello"},"spoken_summary":"A test response"}"""
        val original = decodeResponse(jsonStr)
        val encoded = json.encodeToString(UIResponse.serializer(), original)
        val decoded = decodeResponse(encoded)
        assertEquals("Test", decoded.title)
        assertEquals("A test response", decoded.spokenSummary)
        assertTrue(decoded.layout is UINode.Text)
        assertEquals("Hello", (decoded.layout as UINode.Text).content)
    }

    @Test
    fun `round trip divider`() {
        val original = decodeNode("""{"type":"divider"}""")
        val encoded = json.encodeToString(UINode.serializer(), original)
        val decoded = decodeNode(encoded)
        assertTrue(decoded is UINode.Divider)
    }

    @Test
    fun `empty children array`() {
        val node = decodeNode("""{"type":"vstack","children":[]}""")
        assertTrue(node is UINode.VStack)
        assertEquals(0, (node as UINode.VStack).children.size)
    }

    @Test
    fun `chart empty data`() {
        val node = decodeNode("""{"type":"chart","variant":"bar","data":[]}""")
        assertTrue(node is UINode.Chart)
        assertEquals(0, (node as UINode.Chart).data.size)
    }

    @Test
    fun `list empty items`() {
        val node = decodeNode("""{"type":"list","items":[]}""")
        assertTrue(node is UINode.ListNode)
        assertEquals(0, (node as UINode.ListNode).items.size)
    }

    private fun nodeCount(node: UINode): Int = when (node) {
        is UINode.VStack -> 1 + node.children.sumOf { nodeCount(it) }
        is UINode.HStack -> 1 + node.children.sumOf { nodeCount(it) }
        is UINode.ZStack -> 1 + node.children.sumOf { nodeCount(it) }
        is UINode.Card -> 1 + nodeCount(node.child)
        is UINode.ListNode -> 1 + node.items.sumOf { nodeCount(it) }
        else -> 1
    }

    private fun flattenTree(node: UINode): List<UINode> {
        val result = mutableListOf(node)
        when (node) {
            is UINode.VStack -> node.children.forEach { result += flattenTree(it) }
            is UINode.HStack -> node.children.forEach { result += flattenTree(it) }
            is UINode.ZStack -> node.children.forEach { result += flattenTree(it) }
            is UINode.Card -> result += flattenTree(node.child)
            is UINode.ListNode -> node.items.forEach { result += flattenTree(it) }
            else -> {}
        }
        return result
    }
}
