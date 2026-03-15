package com.generativeui.dsl.snapshot

import com.generativeui.dsl.model.UINode

object RenderSnapshot {

    fun generate(node: UINode, indent: Int = 0): String {
        val sb = StringBuilder()
        appendNode(sb, node, indent, inRow = false)
        return sb.toString().trimEnd()
    }

    private fun appendNode(sb: StringBuilder, node: UINode, indent: Int, inRow: Boolean) {
        val prefix = "  ".repeat(indent)
        when (node) {
            is UINode.VStack -> {
                sb.appendLine("${prefix}VStack(spacing=${node.spacing ?: 8.0}, align=${node.alignment ?: "center"}) [children=${node.children.size}]")
                node.children.forEach { child ->
                    appendNode(sb, child, indent + 1, inRow = false)
                }
            }
            is UINode.HStack -> {
                sb.appendLine("${prefix}HStack(spacing=${node.spacing ?: 8.0}, align=${node.alignment ?: "center"}, fillsWidth=true) [children=${node.children.size}]")
                node.children.forEach { child ->
                    appendNode(sb, child, indent + 1, inRow = true)
                }
            }
            is UINode.ZStack -> {
                sb.appendLine("${prefix}ZStack(align=${node.alignment ?: "center"}) [children=${node.children.size}]")
                node.children.forEach { child ->
                    appendNode(sb, child, indent + 1, inRow = false)
                }
            }
            is UINode.Text -> {
                sb.appendLine("${prefix}Text(content=\"${node.content}\", style=${node.style ?: "body"}, color=${node.color ?: "default"}, weight=${node.weight ?: "regular"})")
            }
            is UINode.Stat -> {
                val weighted = if (inRow) ", weighted=true" else ""
                sb.appendLine("${prefix}Stat(label=\"${node.label}\", value=\"${node.value}\", color=${node.color ?: "default"}, size=${node.size ?: "default"}, icon=${node.icon ?: "none"}, fillsWidth=true${weighted})")
            }
            is UINode.Image -> {
                sb.appendLine("${prefix}Image(name=\"${node.systemName}\", color=${node.color ?: "default"}, size=${node.size ?: "default"})")
            }
            is UINode.Badge -> {
                sb.appendLine("${prefix}Badge(text=\"${node.text}\", color=${node.color ?: "default"})")
            }
            is UINode.Card -> {
                sb.appendLine("${prefix}Card(color=${node.color ?: "default"}, padding=${node.padding ?: 16.0}, cornerRadius=${node.cornerRadius ?: 12.0}, fillsWidth=true)")
                appendNode(sb, node.child, indent + 1, inRow = false)
            }
            is UINode.Progress -> {
                sb.appendLine("${prefix}Progress(value=${node.value}, total=${node.total}, label=${node.label ?: "none"}, color=${node.color ?: "default"})")
            }
            is UINode.Chart -> {
                sb.appendLine("${prefix}Chart(variant=${node.variant}, title=${node.title ?: "none"}) [dataPoints=${node.data.size}]")
                node.data.forEach { dp ->
                    sb.appendLine("${prefix}  DataPoint(label=\"${dp.label}\", value=${dp.value}, color=${dp.color ?: "default"})")
                }
            }
            is UINode.ListNode -> {
                sb.appendLine("${prefix}List [items=${node.items.size}]")
                node.items.forEach { item ->
                    appendNode(sb, item, indent + 1, inRow = false)
                }
            }
            is UINode.Table -> {
                sb.appendLine("${prefix}Table(title=${node.title ?: "none"}, headers=[${node.headers.joinToString(", ") { "\"$it\"" }}]) [rows=${node.rows.size}]")
                node.rows.forEach { row ->
                    sb.appendLine("${prefix}  Row([${row.joinToString(", ") { "\"$it\"" }}])")
                }
            }
            is UINode.Divider -> {
                sb.appendLine("${prefix}Divider")
            }
            is UINode.Spacer -> {
                val weighted = if (inRow) "(weighted=true)" else ""
                sb.appendLine("${prefix}Spacer${weighted}")
            }
            is UINode.Unknown -> {
                sb.appendLine("${prefix}Unknown(type=\"${node.typeName}\")")
            }
        }
    }
}
