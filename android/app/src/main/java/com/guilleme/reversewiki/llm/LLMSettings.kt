package com.guilleme.reversewiki.llm

import android.content.Context
import com.guilleme.reversewiki.security.SecureKeyStore

class LLMSettings(context: Context) {
    private val preferences = context.getSharedPreferences("llm_settings", Context.MODE_PRIVATE)
    private val keys = SecureKeyStore(context)

    var provider: LLMProvider
        get() = runCatching {
            LLMProvider.valueOf(preferences.getString("provider", null) ?: "GEMINI")
        }.getOrDefault(LLMProvider.GEMINI)
        set(value) { preferences.edit().putString("provider", value.name).apply() }

    fun model(provider: LLMProvider = this.provider): String =
        preferences.getString("model.${provider.name}", null) ?: provider.defaultModel

    fun setModel(provider: LLMProvider, model: String) {
        preferences.edit().putString("model.${provider.name}", model).apply()
    }

    fun temperature(provider: LLMProvider, model: String): Double =
        preferences.getFloat("temperature.${provider.name}.$model", 1f).toDouble()

    fun setTemperature(provider: LLMProvider, model: String, value: Double) {
        preferences.edit().putFloat(
            "temperature.${provider.name}.$model",
            value.coerceIn(0.0, 2.0).toFloat(),
        ).apply()
    }

    fun apiKey(provider: LLMProvider = this.provider): String = keys.get(provider)
    fun setApiKey(provider: LLMProvider, value: String) = keys.set(provider, value)

    fun configuration(): LLMConfiguration {
        val current = provider
        val model = model(current)
        return LLMConfiguration(current, apiKey(current), model, temperature(current, model))
    }
}
