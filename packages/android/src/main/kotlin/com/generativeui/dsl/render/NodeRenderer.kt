package com.generativeui.dsl.render

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import com.generativeui.dsl.model.UINode

@Composable
fun RowScope.NodeRendererInRow(node: UINode, modifier: Modifier = Modifier) {
    when (node) {
        is UINode.Spacer -> Spacer(modifier.weight(1f).defaultMinSize(minHeight = 8.dp))
        is UINode.Stat -> StatView(node, modifier.weight(1f))
        else -> NodeRenderer(node, modifier)
    }
}

@Composable
fun NodeRenderer(node: UINode, modifier: Modifier = Modifier) {
    when (node) {
        is UINode.VStack -> VStackView(node, modifier)
        is UINode.HStack -> HStackView(node, modifier)
        is UINode.ZStack -> ZStackView(node, modifier)
        is UINode.Text -> TextView(node, modifier)
        is UINode.Stat -> StatView(node, modifier)
        is UINode.Image -> ImageView(node, modifier)
        is UINode.Badge -> BadgeView(node, modifier)
        is UINode.Card -> CardView(node, modifier)
        is UINode.Progress -> ProgressView(node, modifier)
        is UINode.Chart -> ChartRenderer(node, modifier)
        is UINode.ListNode -> ListView(node, modifier)
        is UINode.Table -> TableView(node, modifier)
        is UINode.Divider -> @Suppress("DEPRECATION") Divider(modifier)
        is UINode.Spacer -> Spacer(modifier.defaultMinSize(minHeight = 8.dp))
        is UINode.Unknown -> UnknownView(node, modifier)
    }
}

@Composable
private fun VStackView(node: UINode.VStack, modifier: Modifier) {
    val horizontalAlignment = when (node.alignment) {
        "leading" -> Alignment.Start
        "trailing" -> Alignment.End
        else -> Alignment.CenterHorizontally
    }
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy((node.spacing ?: 8.0).dp),
        horizontalAlignment = horizontalAlignment
    ) {
        node.children.forEach { child ->
            NodeRenderer(child)
        }
    }
}

@Composable
private fun HStackView(node: UINode.HStack, modifier: Modifier) {
    val verticalAlignment = when (node.alignment) {
        "top" -> Alignment.Top
        "bottom" -> Alignment.Bottom
        else -> Alignment.CenterVertically
    }
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy((node.spacing ?: 8.0).dp),
        verticalAlignment = verticalAlignment
    ) {
        node.children.forEach { child ->
            NodeRendererInRow(child)
        }
    }
}

@Composable
private fun ZStackView(node: UINode.ZStack, modifier: Modifier) {
    Box(modifier = modifier) {
        node.children.forEach { child ->
            NodeRenderer(child)
        }
    }
}

@Composable
private fun TextView(node: UINode.Text, modifier: Modifier) {
    val style = resolveTextStyle(node.style)
    val color = resolveColorWithTheme(node.color)
    val fontWeight = resolveFontWeight(node.weight)

    Text(
        text = node.content,
        modifier = modifier,
        style = style,
        color = color,
        fontWeight = fontWeight,
        maxLines = node.maxLines ?: Int.MAX_VALUE,
        overflow = TextOverflow.Ellipsis
    )
}

@Composable
private fun StatView(node: UINode.Stat, modifier: Modifier) {
    val isLarge = node.size == "large"
    val accentColor = resolveColor(node.color) ?: MaterialTheme.colorScheme.primary

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        if (node.icon != null) {
            Icon(
                imageVector = resolveIcon(node.icon),
                contentDescription = node.label,
                tint = accentColor,
                modifier = Modifier.size(if (isLarge) 28.dp else 20.dp)
            )
        }
        Text(
            text = node.label,
            style = if (isLarge) MaterialTheme.typography.titleSmall else MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        AutoSizeText(
            text = node.value,
            maxFontSize = if (isLarge) 32.sp else 22.sp,
            minFontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            color = resolveColor(node.color) ?: MaterialTheme.colorScheme.onSurface
        )
    }
}

@Composable
private fun ImageView(node: UINode.Image, modifier: Modifier) {
    val iconSize = when (node.size) {
        "small" -> 20.dp
        "large" -> 32.dp
        "xlarge" -> 48.dp
        else -> 24.dp
    }
    val tint = resolveColor(node.color) ?: MaterialTheme.colorScheme.primary

    Icon(
        imageVector = resolveIcon(node.systemName),
        contentDescription = node.systemName,
        modifier = modifier.size(iconSize),
        tint = tint
    )
}

@Composable
private fun BadgeView(node: UINode.Badge, modifier: Modifier) {
    val badgeColor = resolveColor(node.color) ?: MaterialTheme.colorScheme.primary

    Text(
        text = node.text,
        modifier = modifier
            .clip(CircleShape)
            .background(badgeColor.copy(alpha = 0.15f))
            .padding(horizontal = 10.dp, vertical = 4.dp),
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.Medium,
        color = badgeColor
    )
}

@Composable
private fun CardView(node: UINode.Card, modifier: Modifier) {
    val bgColor = resolveColor(node.color)?.copy(alpha = 0.08f)
        ?: MaterialTheme.colorScheme.surfaceVariant
    val cornerRadius = (node.cornerRadius ?: 12.0).dp
    val padding = (node.padding ?: 16.0).dp

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(cornerRadius))
            .background(bgColor)
            .padding(padding)
    ) {
        NodeRenderer(node.child)
    }
}

@Composable
private fun ProgressView(node: UINode.Progress, modifier: Modifier) {
    val progressColor = resolveColor(node.color) ?: MaterialTheme.colorScheme.primary
    val fraction = (node.value / node.total).coerceIn(0.0, 1.0).toFloat()

    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        if (node.label != null) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = node.label,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = "${(fraction * 100).toInt()}%",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        @Suppress("DEPRECATION")
        LinearProgressIndicator(
            progress = fraction,
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp)
                .clip(RoundedCornerShape(4.dp)),
            color = progressColor,
            trackColor = MaterialTheme.colorScheme.surfaceVariant,
        )
    }
}

@Composable
private fun ListView(node: UINode.ListNode, modifier: Modifier) {
    Column(modifier = modifier) {
        node.items.forEachIndexed { index, item ->
            Box(modifier = Modifier.padding(vertical = 10.dp, horizontal = 4.dp)) {
                NodeRenderer(item)
            }
            if (index < node.items.size - 1) {
                @Suppress("DEPRECATION") Divider()
            }
        }
    }
}

@Composable
private fun TableView(node: UINode.Table, modifier: Modifier) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (node.title != null) {
            Text(
                text = node.title,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Medium
            )
        }
        if (node.headers.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(6.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(horizontal = 8.dp, vertical = 6.dp)
            ) {
                node.headers.forEach { header ->
                    Text(
                        text = header,
                        modifier = Modifier.weight(1f),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            @Suppress("DEPRECATION") Divider()
        }
        node.rows.forEachIndexed { index, row ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 6.dp)
            ) {
                row.forEach { cell ->
                    Text(
                        text = cell,
                        modifier = Modifier.weight(1f),
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }
            if (index < node.rows.size - 1) {
                @Suppress("DEPRECATION") Divider()
            }
        }
    }
}

@Composable
private fun UnknownView(node: UINode.Unknown, modifier: Modifier) {
    Text(
        text = "Unknown: ${node.typeName}",
        modifier = modifier,
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
}

/**
 * Text that auto-shrinks font size to fit within available width.
 * Mirrors iOS's `.minimumScaleFactor(0.6)` behavior.
 */
@Composable
private fun AutoSizeText(
    text: String,
    maxFontSize: TextUnit,
    minFontSize: TextUnit,
    fontWeight: FontWeight,
    color: Color,
    modifier: Modifier = Modifier
) {
    var fontSize by remember { mutableStateOf(maxFontSize) }
    var readyToDraw by remember { mutableStateOf(false) }

    Text(
        text = text,
        modifier = modifier.drawWithContent { if (readyToDraw) drawContent() },
        fontSize = fontSize,
        fontWeight = fontWeight,
        color = color,
        softWrap = false,
        maxLines = 1,
        textAlign = TextAlign.Center,
        onTextLayout = { result ->
            if (result.didOverflowWidth && fontSize > minFontSize) {
                fontSize *= 0.85f
            } else {
                readyToDraw = true
            }
        }
    )
}
