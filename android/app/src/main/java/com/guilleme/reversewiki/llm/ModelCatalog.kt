package com.guilleme.reversewiki.llm

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.JsonObject
import okhttp3.OkHttpClient
import okhttp3.Request

class ModelCatalog(private val http: OkHttpClient = OkHttpClient()) {
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun models(provider: LLMProvider, apiKey: String): List<LLMModel> = withContext(Dispatchers.IO) {
        if (apiKey.isBlank()) return@withContext emptyList()
        val request = when (provider) {
            LLMProvider.GEMINI -> Request.Builder()
                .url("https://generativelanguage.googleapis.com/v1beta/models")
                .header("x-goog-api-key", apiKey).build()
            LLMProvider.ANTHROPIC -> Request.Builder().url("https://api.anthropic.com/v1/models")
                .header("x-api-key", apiKey).header("anthropic-version", "2023-06-01").build()
            else -> Request.Builder().url(provider.endpoint!!.substringBeforeLast('/') + "/models")
                .header("Authorization", "Bearer $apiKey").build()
        }
        http.newCall(request).execute().use { response ->
            if (!response.isSuccessful) error("Erreur API ${response.code}")
            val root = json.parseToJsonElement(response.body.string()).jsonObject
            val array = root[if (provider == LLMProvider.GEMINI) "models" else "data"]?.jsonArray.orEmpty()
            array.mapNotNull { item ->
                val objectValue = item.jsonObject
                val raw = objectValue[if (provider == LLMProvider.GEMINI) "name" else "id"]
                    ?.jsonPrimitive?.contentOrNull?.removePrefix("models/") ?: return@mapNotNull null
                raw.takeIf { supportsImages(provider, it, objectValue) }?.let(::LLMModel)
            }.sortedBy { it.id }
        }
    }

    private fun supportsImages(provider: LLMProvider, id: String, metadata: JsonObject): Boolean {
        val value = id.lowercase()
        val excluded = listOf("embed", "tts", "audio", "realtime", "moderation", "image-preview")
        if (excluded.any(value::contains)) return false
        return when (provider) {
            LLMProvider.GEMINI -> value.contains("gemini")
            LLMProvider.ANTHROPIC -> value.contains("claude")
            LLMProvider.OPENAI -> value.contains("gpt-4") || value.contains("gpt-5") || value.contains("o3")
            LLMProvider.KIMI -> value.contains("k2.5") || value.contains("k2.6") || value.contains("k3")
            LLMProvider.OPENROUTER -> metadata["architecture"]?.jsonObject
                ?.get("input_modalities")?.jsonArray
                ?.any { it.jsonPrimitive.contentOrNull == "image" } == true
        }
    }
}
