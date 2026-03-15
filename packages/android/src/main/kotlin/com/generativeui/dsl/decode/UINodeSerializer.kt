package com.generativeui.dsl.decode

import com.generativeui.dsl.model.ChartDataPoint
import com.generativeui.dsl.model.UINode
import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.buildClassSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.*
import java.util.UUID

object UINodeSerializer : KSerializer<UINode> {
    override val descriptor: SerialDescriptor = buildClassSerialDescriptor("UINode")

    override fun deserialize(deserializer: Decoder): UINode {
        val jsonDecoder = deserializer as? JsonDecoder
            ?: error("UINodeSerializer only supports JSON")
        val element = jsonDecoder.decodeJsonElement().jsonObject
        return decodeNode(element)
    }

    override fun serialize(encoder: Encoder, value: UINode) {
        val jsonEncoder = encoder as? JsonEncoder
            ?: error("UINodeSerializer only supports JSON")
        jsonEncoder.encodeJsonElement(encodeNode(value))
    }

    fun decodeNode(obj: JsonObject): UINode {
        val type = obj["type"]?.jsonPrimitive?.contentOrNull
            ?: throw IllegalArgumentException("UINode missing 'type' field")
        val id = UUID.randomUUID().toString()

        return when (type) {
            "vstack" -> UINode.VStack(
                id = id,
                spacing = obj["spacing"]?.jsonPrimitive?.doubleOrNull,
                alignment = obj["alignment"]?.jsonPrimitive?.contentOrNull,
                children = decodeFaultTolerantArray(obj["children"]?.jsonArray ?: JsonArray(emptyList()))
            )
            "hstack" -> UINode.HStack(
                id = id,
                spacing = obj["spacing"]?.jsonPrimitive?.doubleOrNull,
                alignment = obj["alignment"]?.jsonPrimitive?.contentOrNull,
                children = decodeFaultTolerantArray(obj["children"]?.jsonArray ?: JsonArray(emptyList()))
            )
            "zstack" -> UINode.ZStack(
                id = id,
                alignment = obj["alignment"]?.jsonPrimitive?.contentOrNull,
                children = decodeFaultTolerantArray(obj["children"]?.jsonArray ?: JsonArray(emptyList()))
            )
            "text" -> UINode.Text(
                id = id,
                content = obj["content"]?.jsonPrimitive?.content ?: "",
                style = obj["style"]?.jsonPrimitive?.contentOrNull,
                color = obj["color"]?.jsonPrimitive?.contentOrNull,
                weight = obj["weight"]?.jsonPrimitive?.contentOrNull,
                maxLines = obj["maxLines"]?.jsonPrimitive?.intOrNull
            )
            "stat" -> UINode.Stat(
                id = id,
                label = obj["label"]?.jsonPrimitive?.content ?: "",
                value = obj["value"]?.jsonPrimitive?.content ?: "",
                color = obj["color"]?.jsonPrimitive?.contentOrNull,
                size = obj["size"]?.jsonPrimitive?.contentOrNull,
                icon = obj["icon"]?.jsonPrimitive?.contentOrNull
            )
            "image" -> UINode.Image(
                id = id,
                systemName = obj["system_name"]?.jsonPrimitive?.content ?: "",
                color = obj["color"]?.jsonPrimitive?.contentOrNull,
                size = obj["size"]?.jsonPrimitive?.contentOrNull
            )
            "badge" -> UINode.Badge(
                id = id,
                text = obj["text"]?.jsonPrimitive?.content ?: "",
                color = obj["color"]?.jsonPrimitive?.contentOrNull
            )
            "card" -> {
                val childObj = obj["child"]?.jsonObject
                    ?: throw IllegalArgumentException("Card missing 'child' field")
                UINode.Card(
                    id = id,
                    color = obj["color"]?.jsonPrimitive?.contentOrNull,
                    padding = obj["padding"]?.jsonPrimitive?.doubleOrNull,
                    cornerRadius = obj["cornerRadius"]?.jsonPrimitive?.doubleOrNull,
                    child = decodeNode(childObj)
                )
            }
            "progress" -> UINode.Progress(
                id = id,
                value = obj["value"]?.jsonPrimitive?.double ?: 0.0,
                total = obj["total"]?.jsonPrimitive?.doubleOrNull ?: 1.0,
                label = obj["label"]?.jsonPrimitive?.contentOrNull,
                color = obj["color"]?.jsonPrimitive?.contentOrNull
            )
            "chart" -> UINode.Chart(
                id = id,
                variant = obj["variant"]?.jsonPrimitive?.content ?: "bar",
                title = obj["title"]?.jsonPrimitive?.contentOrNull,
                data = obj["data"]?.jsonArray?.map { elem ->
                    val dp = elem.jsonObject
                    ChartDataPoint(
                        label = dp["label"]?.jsonPrimitive?.content ?: "",
                        value = dp["value"]?.jsonPrimitive?.double ?: 0.0,
                        color = dp["color"]?.jsonPrimitive?.contentOrNull
                    )
                } ?: emptyList()
            )
            "list" -> UINode.ListNode(
                id = id,
                items = decodeFaultTolerantArray(obj["items"]?.jsonArray ?: JsonArray(emptyList()))
            )
            "table" -> UINode.Table(
                id = id,
                title = obj["title"]?.jsonPrimitive?.contentOrNull,
                headers = obj["headers"]?.jsonArray?.map { it.jsonPrimitive.content } ?: emptyList(),
                rows = obj["rows"]?.jsonArray?.map { row ->
                    row.jsonArray.map { it.jsonPrimitive.content }
                } ?: emptyList()
            )
            "divider" -> UINode.Divider(id = id)
            "spacer" -> UINode.Spacer(id = id)
            else -> UINode.Unknown(id = id, typeName = type)
        }
    }

    private fun decodeFaultTolerantArray(array: JsonArray): List<UINode> {
        return array.mapNotNull { element ->
            try {
                decodeNode(element.jsonObject)
            } catch (_: Exception) {
                null
            }
        }
    }

    private fun encodeNode(node: UINode): JsonObject = buildJsonObject {
        when (node) {
            is UINode.VStack -> {
                put("type", JsonPrimitive("vstack"))
                node.spacing?.let { put("spacing", JsonPrimitive(it)) }
                node.alignment?.let { put("alignment", JsonPrimitive(it)) }
                put("children", JsonArray(node.children.map { encodeNode(it) }))
            }
            is UINode.HStack -> {
                put("type", JsonPrimitive("hstack"))
                node.spacing?.let { put("spacing", JsonPrimitive(it)) }
                node.alignment?.let { put("alignment", JsonPrimitive(it)) }
                put("children", JsonArray(node.children.map { encodeNode(it) }))
            }
            is UINode.ZStack -> {
                put("type", JsonPrimitive("zstack"))
                node.alignment?.let { put("alignment", JsonPrimitive(it)) }
                put("children", JsonArray(node.children.map { encodeNode(it) }))
            }
            is UINode.Text -> {
                put("type", JsonPrimitive("text"))
                put("content", JsonPrimitive(node.content))
                node.style?.let { put("style", JsonPrimitive(it)) }
                node.color?.let { put("color", JsonPrimitive(it)) }
                node.weight?.let { put("weight", JsonPrimitive(it)) }
                node.maxLines?.let { put("maxLines", JsonPrimitive(it)) }
            }
            is UINode.Stat -> {
                put("type", JsonPrimitive("stat"))
                put("label", JsonPrimitive(node.label))
                put("value", JsonPrimitive(node.value))
                node.color?.let { put("color", JsonPrimitive(it)) }
                node.size?.let { put("size", JsonPrimitive(it)) }
                node.icon?.let { put("icon", JsonPrimitive(it)) }
            }
            is UINode.Image -> {
                put("type", JsonPrimitive("image"))
                put("system_name", JsonPrimitive(node.systemName))
                node.color?.let { put("color", JsonPrimitive(it)) }
                node.size?.let { put("size", JsonPrimitive(it)) }
            }
            is UINode.Badge -> {
                put("type", JsonPrimitive("badge"))
                put("text", JsonPrimitive(node.text))
                node.color?.let { put("color", JsonPrimitive(it)) }
            }
            is UINode.Card -> {
                put("type", JsonPrimitive("card"))
                node.color?.let { put("color", JsonPrimitive(it)) }
                node.padding?.let { put("padding", JsonPrimitive(it)) }
                node.cornerRadius?.let { put("cornerRadius", JsonPrimitive(it)) }
                put("child", encodeNode(node.child))
            }
            is UINode.Progress -> {
                put("type", JsonPrimitive("progress"))
                put("value", JsonPrimitive(node.value))
                if (node.total != 1.0) put("total", JsonPrimitive(node.total))
                node.label?.let { put("label", JsonPrimitive(it)) }
                node.color?.let { put("color", JsonPrimitive(it)) }
            }
            is UINode.Chart -> {
                put("type", JsonPrimitive("chart"))
                put("variant", JsonPrimitive(node.variant))
                node.title?.let { put("title", JsonPrimitive(it)) }
                put("data", JsonArray(node.data.map { dp ->
                    buildJsonObject {
                        put("label", JsonPrimitive(dp.label))
                        put("value", JsonPrimitive(dp.value))
                        dp.color?.let { put("color", JsonPrimitive(it)) }
                    }
                }))
            }
            is UINode.ListNode -> {
                put("type", JsonPrimitive("list"))
                put("items", JsonArray(node.items.map { encodeNode(it) }))
            }
            is UINode.Table -> {
                put("type", JsonPrimitive("table"))
                node.title?.let { put("title", JsonPrimitive(it)) }
                put("headers", JsonArray(node.headers.map { JsonPrimitive(it) }))
                put("rows", JsonArray(node.rows.map { row ->
                    JsonArray(row.map { JsonPrimitive(it) })
                }))
            }
            is UINode.Divider -> {
                put("type", JsonPrimitive("divider"))
            }
            is UINode.Spacer -> {
                put("type", JsonPrimitive("spacer"))
            }
            is UINode.Unknown -> {
                put("type", JsonPrimitive(node.typeName))
            }
        }
    }
}
