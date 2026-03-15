package com.generativeui.dsl.render

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.generativeui.dsl.model.UINode

@Composable
fun ChartRenderer(node: UINode.Chart, modifier: Modifier = Modifier) {
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

        when (node.variant) {
            "bar" -> BarChart(node)
            "pie" -> PieChart(node)
            "line" -> LineChart(node)
            else -> BarChart(node)
        }
    }
}

@Composable
private fun BarChart(node: UINode.Chart) {
    if (node.data.isEmpty()) return
    val maxValue = node.data.maxOf { it.value }
    if (maxValue <= 0) return

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        node.data.forEach { point ->
            val fraction = (point.value / maxValue).toFloat()
            val barColor = resolveColor(point.color) ?: MaterialTheme.colorScheme.primary

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = point.label,
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier.width(72.dp)
                )
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(24.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxHeight()
                            .fillMaxWidth(fraction)
                            .clip(RoundedCornerShape(4.dp))
                            .background(barColor)
                    )
                }
                Text(
                    text = String.format("%.0f", point.value),
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier.width(48.dp)
                )
            }
        }
    }
}

@Composable
private fun PieChart(node: UINode.Chart) {
    if (node.data.isEmpty()) return
    val total = node.data.sumOf { it.value }
    if (total <= 0) return

    val colors = node.data.map { resolveColor(it.color) ?: MaterialTheme.colorScheme.primary }

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Canvas(
            modifier = Modifier
                .size(180.dp)
                .padding(8.dp)
        ) {
            val diameter = size.minDimension
            val topLeft = Offset(
                (size.width - diameter) / 2f,
                (size.height - diameter) / 2f
            )
            val arcSize = Size(diameter, diameter)

            var startAngle = -90f
            node.data.forEachIndexed { index, point ->
                val sweep = (point.value / total * 360.0).toFloat()
                drawArc(
                    color = colors[index],
                    startAngle = startAngle,
                    sweepAngle = sweep,
                    useCenter = true,
                    topLeft = topLeft,
                    size = arcSize
                )
                startAngle += sweep
            }
        }

        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            node.data.forEachIndexed { index, point ->
                val pct = (point.value / total * 100).toInt()
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .clip(RoundedCornerShape(2.dp))
                            .background(colors[index])
                    )
                    Text(
                        text = point.label,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.weight(1f)
                    )
                    Text(
                        text = "$pct%",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun LineChart(node: UINode.Chart) {
    if (node.data.isEmpty()) return
    val maxValue = node.data.maxOf { it.value }
    if (maxValue <= 0) return

    val lineColor = resolveColor(node.data.first().color) ?: MaterialTheme.colorScheme.primary
    val highlightColors = node.data.map { resolveColor(it.color) ?: lineColor }

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(160.dp)
                .padding(start = 8.dp, end = 8.dp, top = 8.dp, bottom = 4.dp)
        ) {
            val n = node.data.size
            if (n < 2) return@Canvas

            val paddingH = 24f
            val paddingV = 20f
            val chartWidth = size.width - paddingH * 2
            val chartHeight = size.height - paddingV * 2
            val stepX = chartWidth / (n - 1)

            val points = node.data.mapIndexed { i, point ->
                val x = paddingH + i * stepX
                val y = paddingV + chartHeight * (1f - (point.value / maxValue).toFloat())
                Offset(x, y)
            }

            for (i in 0..3) {
                val y = paddingV + chartHeight * i / 3f
                drawLine(
                    color = Color.LightGray.copy(alpha = 0.4f),
                    start = Offset(paddingH, y),
                    end = Offset(size.width - paddingH, y),
                    strokeWidth = 1f
                )
            }

            for (i in 0 until points.size - 1) {
                drawLine(
                    color = lineColor,
                    start = points[i],
                    end = points[i + 1],
                    strokeWidth = 3.dp.toPx(),
                    cap = StrokeCap.Round
                )
            }

            points.forEachIndexed { i, pt ->
                drawCircle(
                    color = highlightColors[i],
                    radius = 5.dp.toPx(),
                    center = pt
                )
                drawCircle(
                    color = Color.White,
                    radius = 2.5.dp.toPx(),
                    center = pt
                )
            }
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 32.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            node.data.forEach { point ->
                Text(
                    text = point.label,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}
