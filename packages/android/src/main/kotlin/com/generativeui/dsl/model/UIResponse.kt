package com.generativeui.dsl.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class UIResponse(
    val title: String,
    val layout: UINode,
    @SerialName("spoken_summary") val spokenSummary: String
)
