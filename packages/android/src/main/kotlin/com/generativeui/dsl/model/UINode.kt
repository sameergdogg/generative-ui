package com.generativeui.dsl.model

import com.generativeui.dsl.decode.UINodeSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * A recursive UI node that the LLM generates to describe arbitrary layouts.
 * Mirrors the Swift UINode enum — same JSON, native renderers per platform.
 */
@Serializable(with = UINodeSerializer::class)
sealed class UINode {
    abstract val id: String

    // -- Layout Nodes --

    @Serializable
    data class VStack(
        override val id: String,
        val spacing: Double? = null,
        val alignment: String? = null,
        val children: List<UINode>
    ) : UINode()

    @Serializable
    data class HStack(
        override val id: String,
        val spacing: Double? = null,
        val alignment: String? = null,
        val children: List<UINode>
    ) : UINode()

    @Serializable
    data class ZStack(
        override val id: String,
        val alignment: String? = null,
        val children: List<UINode>
    ) : UINode()

    // -- Content Nodes --

    @Serializable
    data class Text(
        override val id: String,
        val content: String,
        val style: String? = null,
        val color: String? = null,
        val weight: String? = null,
        val maxLines: Int? = null
    ) : UINode()

    @Serializable
    data class Stat(
        override val id: String,
        val label: String,
        val value: String,
        val color: String? = null,
        val size: String? = null,
        val icon: String? = null
    ) : UINode()

    @Serializable
    data class Image(
        override val id: String,
        @SerialName("system_name") val systemName: String,
        val color: String? = null,
        val size: String? = null
    ) : UINode()

    @Serializable
    data class Badge(
        override val id: String,
        val text: String,
        val color: String? = null
    ) : UINode()

    @Serializable
    data class Card(
        override val id: String,
        val color: String? = null,
        val padding: Double? = null,
        val cornerRadius: Double? = null,
        val child: UINode
    ) : UINode()

    @Serializable
    data class Progress(
        override val id: String,
        val value: Double,
        val total: Double = 1.0,
        val label: String? = null,
        val color: String? = null
    ) : UINode()

    @Serializable
    data class Chart(
        override val id: String,
        val variant: String,
        val title: String? = null,
        val data: List<ChartDataPoint>
    ) : UINode()

    @Serializable
    data class ListNode(
        override val id: String,
        val items: List<UINode>
    ) : UINode()

    @Serializable
    data class Table(
        override val id: String,
        val title: String? = null,
        val headers: List<String> = emptyList(),
        val rows: List<List<String>> = emptyList()
    ) : UINode()

    @Serializable
    data class Divider(
        override val id: String
    ) : UINode()

    @Serializable
    data class Spacer(
        override val id: String
    ) : UINode()

    /** Graceful fallback for unknown node types — matches Swift's "Unknown: X" behavior */
    @Serializable
    data class Unknown(
        override val id: String,
        val typeName: String
    ) : UINode()
}

@Serializable
data class ChartDataPoint(
    val label: String,
    val value: Double,
    val color: String? = null
)
