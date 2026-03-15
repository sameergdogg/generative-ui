import Foundation

/// Produces a canonical, deterministic text description of a UINode tree's
/// rendering behavior. Both iOS (Swift) and Android (Kotlin) generate these
/// snapshots from the same JSON fixtures — if they match, the renderers
/// produce structurally identical output.
///
/// Must produce byte-identical output to `RenderSnapshot.kt` for the same input.
public struct RenderSnapshot {

    /// Generate a snapshot for a UINode tree.
    public static func generate(_ node: UINode) -> String {
        var lines: [String] = []
        appendNode(&lines, node, indent: 0, inRow: false)
        return lines.joined(separator: "\n")
    }

    private static func appendNode(_ lines: inout [String], _ node: UINode, indent: Int, inRow: Bool) {
        let prefix = String(repeating: "  ", count: indent)

        switch node {
        case .vstack(let n):
            lines.append("\(prefix)VStack(spacing=\(n.spacing ?? 8), align=\(n.alignment ?? "center")) [children=\(n.children.count)]")
            for child in n.children {
                appendNode(&lines, child, indent: indent + 1, inRow: false)
            }

        case .hstack(let n):
            lines.append("\(prefix)HStack(spacing=\(n.spacing ?? 8), align=\(n.alignment ?? "center"), fillsWidth=true) [children=\(n.children.count)]")
            for child in n.children {
                appendNode(&lines, child, indent: indent + 1, inRow: true)
            }

        case .zstack(let n):
            lines.append("\(prefix)ZStack(align=\(n.alignment ?? "center")) [children=\(n.children.count)]")
            for child in n.children {
                appendNode(&lines, child, indent: indent + 1, inRow: false)
            }

        case .text(let n):
            lines.append("\(prefix)Text(content=\"\(n.content)\", style=\(n.style ?? "body"), color=\(n.color ?? "default"), weight=\(n.weight ?? "regular"))")

        case .stat(let n):
            let weighted = inRow ? ", weighted=true" : ""
            lines.append("\(prefix)Stat(label=\"\(n.label)\", value=\"\(n.value)\", color=\(n.color ?? "default"), size=\(n.size ?? "default"), icon=\(n.icon ?? "none"), fillsWidth=true\(weighted))")

        case .image(let n):
            lines.append("\(prefix)Image(name=\"\(n.systemName)\", color=\(n.color ?? "default"), size=\(n.size ?? "default"))")

        case .badge(let n):
            lines.append("\(prefix)Badge(text=\"\(n.text)\", color=\(n.color ?? "default"))")

        case .card(let n):
            lines.append("\(prefix)Card(color=\(n.color ?? "default"), padding=\(n.padding ?? 16), cornerRadius=\(n.cornerRadius ?? 12), fillsWidth=true)")
            appendNode(&lines, n.child, indent: indent + 1, inRow: false)

        case .progress(let n):
            lines.append("\(prefix)Progress(value=\(n.value), total=\(n.total), label=\(n.label ?? "none"), color=\(n.color ?? "default"))")

        case .chart(let n):
            lines.append("\(prefix)Chart(variant=\(n.variant), title=\(n.title ?? "none")) [dataPoints=\(n.data.count)]")
            for dp in n.data {
                lines.append("\(prefix)  DataPoint(label=\"\(dp.label)\", value=\(dp.value), color=\(dp.color ?? "default"))")
            }

        case .list(let n):
            lines.append("\(prefix)List [items=\(n.items.count)]")
            for item in n.items {
                appendNode(&lines, item, indent: indent + 1, inRow: false)
            }

        case .table(let n):
            let headers = n.headers.map { "\"\($0)\"" }.joined(separator: ", ")
            lines.append("\(prefix)Table(title=\(n.title ?? "none"), headers=[\(headers)]) [rows=\(n.rows.count)]")
            for row in n.rows {
                let cells = row.map { "\"\($0)\"" }.joined(separator: ", ")
                lines.append("\(prefix)  Row([\(cells)])")
            }

        case .divider:
            lines.append("\(prefix)Divider")

        case .spacer:
            let weighted = inRow ? "(weighted=true)" : ""
            lines.append("\(prefix)Spacer\(weighted)")
        }
    }
}
