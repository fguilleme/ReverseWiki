package com.guilleme.reversewiki.llm

import android.util.Base64
import android.util.Log
import com.guilleme.reversewiki.model.GeoPoint
import com.guilleme.reversewiki.model.PlaceFact
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.Locale
import java.util.concurrent.TimeUnit

interface LLMClient {
    suspend fun fetchFact(image: ByteArray, point: GeoPoint?): PlaceFact
}

class RemoteLLMClient(
    private val configuration: LLMConfiguration,
    private val http: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(180, TimeUnit.SECONDS)
        .build(),
) : LLMClient {
    private val json = Json { ignoreUnknownKeys = true }

    override suspend fun fetchFact(image: ByteArray, point: GeoPoint?): PlaceFact =
        withContext(Dispatchers.IO) {
            require(configuration.apiKey.isNotBlank()) {
                "Ajoutez une clé API ${configuration.provider.displayName}."
            }
            val system = FactPrompt.system(Locale.getDefault().displayLanguage)
            val user = FactPrompt.user(point)
            val request = when (configuration.provider) {
                LLMProvider.ANTHROPIC -> anthropicRequest(image, system, user)
                LLMProvider.GEMINI -> geminiRequest(image, system, user)
                else -> openAIRequest(image, system, user)
            }
            val started = System.nanoTime()
            http.newCall(request).execute().use { response ->
                val body = response.body.string()
                Log.i("LLMExchange", "provider=${configuration.provider} model=${configuration.model} status=${response.code} bytes=${body.length} durationMs=${(System.nanoTime() - started) / 1_000_000}")
                if (!response.isSuccessful) error("Erreur API ${response.code} : ${errorMessage(body)}")
                FactPrompt.decode(extractText(body))
            }
        }

    private fun anthropicRequest(image: ByteArray, system: String, user: String): Request {
        val payload = buildJsonObject {
            put("model", JsonPrimitive(configuration.model))
            put("max_tokens", JsonPrimitive(4096))
            put("temperature", JsonPrimitive(configuration.temperature))
            put("system", JsonPrimitive(system))
            put("messages", buildJsonArray {
                add(buildJsonObject {
                    put("role", JsonPrimitive("user"))
                    put("content", buildJsonArray {
                        add(buildJsonObject {
                            put("type", JsonPrimitive("image"))
                            put("source", buildJsonObject {
                                put("type", JsonPrimitive("base64"))
                                put("media_type", JsonPrimitive("image/jpeg"))
                                put("data", JsonPrimitive(Base64.encodeToString(image, Base64.NO_WRAP)))
                            })
                        })
                        add(buildJsonObject { put("type", JsonPrimitive("text")); put("text", JsonPrimitive(user)) })
                    })
                })
            })
        }
        return post(configuration.provider.endpoint!!, payload).newBuilder()
            .header("x-api-key", configuration.apiKey)
            .header("anthropic-version", "2023-06-01")
            .build()
    }

    private fun geminiRequest(image: ByteArray, system: String, user: String): Request {
        val payload = buildJsonObject {
            put("system_instruction", buildJsonObject {
                put("parts", buildJsonArray { add(buildJsonObject { put("text", JsonPrimitive(system)) }) })
            })
            put("contents", buildJsonArray { add(buildJsonObject {
                put("role", JsonPrimitive("user"))
                put("parts", buildJsonArray {
                    add(buildJsonObject { put("text", JsonPrimitive(user)) })
                    add(buildJsonObject { put("inline_data", buildJsonObject {
                        put("mime_type", JsonPrimitive("image/jpeg"))
                        put("data", JsonPrimitive(Base64.encodeToString(image, Base64.NO_WRAP)))
                    }) })
                })
            }) })
            put("generationConfig", buildJsonObject {
                put("temperature", JsonPrimitive(configuration.temperature))
                put("responseMimeType", JsonPrimitive("application/json"))
            })
        }
        val url = "https://generativelanguage.googleapis.com/v1beta/models/${configuration.model}:generateContent"
        return post(url, payload).newBuilder().header("x-goog-api-key", configuration.apiKey).build()
    }

    private fun openAIRequest(image: ByteArray, system: String, user: String): Request {
        val payload = buildJsonObject {
            put("model", JsonPrimitive(configuration.model))
            put("temperature", JsonPrimitive(configuration.temperature))
            put("messages", buildJsonArray {
                add(buildJsonObject { put("role", JsonPrimitive("system")); put("content", JsonPrimitive(system)) })
                add(buildJsonObject {
                    put("role", JsonPrimitive("user"))
                    put("content", buildJsonArray {
                        add(buildJsonObject { put("type", JsonPrimitive("text")); put("text", JsonPrimitive(user)) })
                        add(buildJsonObject { put("type", JsonPrimitive("image_url")); put("image_url", buildJsonObject {
                            put("url", JsonPrimitive("data:image/jpeg;base64,${Base64.encodeToString(image, Base64.NO_WRAP)}"))
                        }) })
                    })
                })
            })
        }
        return post(configuration.provider.endpoint!!, payload).newBuilder()
            .header("Authorization", "Bearer ${configuration.apiKey}")
            .build()
    }

    private fun post(url: String, body: JsonObject): Request = Request.Builder().url(url)
        .post(body.toString().toRequestBody("application/json".toMediaType()))
        .header("Content-Type", "application/json")
        .build()

    private fun extractText(body: String): String {
        val root = json.parseToJsonElement(body).jsonObject
        return when (configuration.provider) {
            LLMProvider.ANTHROPIC -> root["content"]!!.jsonArray
                .mapNotNull { it.jsonObject["text"]?.jsonPrimitive?.contentOrNull }.joinToString("")
            LLMProvider.GEMINI -> root["candidates"]!!.jsonArray.first().jsonObject["content"]!!
                .jsonObject["parts"]!!.jsonArray.first().jsonObject["text"]!!.jsonPrimitive.content
            else -> root["choices"]!!.jsonArray.first().jsonObject["message"]!!
                .jsonObject["content"]!!.jsonPrimitive.content
        }
    }

    private fun errorMessage(body: String): String = runCatching {
        json.parseToJsonElement(body).jsonObject["error"]?.jsonObject
            ?.get("message")?.jsonPrimitive?.content ?: body.take(1000)
    }.getOrDefault(body.take(1000))
}
