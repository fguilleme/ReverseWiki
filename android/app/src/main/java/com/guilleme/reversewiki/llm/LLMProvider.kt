package com.guilleme.reversewiki.llm

enum class LLMProvider(
    val displayName: String,
    val defaultModel: String,
    val endpoint: String?,
    val keyUrl: String?,
) {
    ANTHROPIC(
        "Anthropic", "claude-sonnet-4-5", "https://api.anthropic.com/v1/messages",
        "https://console.anthropic.com/settings/keys",
    ),
    OPENAI(
        "OpenAI", "gpt-4.1-mini", "https://api.openai.com/v1/chat/completions",
        "https://platform.openai.com/api-keys",
    ),
    GEMINI(
        "Gemini", "gemini-2.5-flash-lite", null,
        "https://aistudio.google.com/app/apikey",
    ),
    KIMI(
        "Kimi", "kimi-k2.5", "https://api.moonshot.ai/v1/chat/completions",
        "https://platform.moonshot.ai/console/api-keys",
    ),
    OPENROUTER(
        "OpenRouter", "anthropic/claude-sonnet-4.5",
        "https://openrouter.ai/api/v1/chat/completions", "https://openrouter.ai/settings/keys",
    );

    fun acceptsMediumConfidence(model: String): Boolean = when (this) {
        ANTHROPIC, OPENAI -> true
        OPENROUTER -> model.startsWith("anthropic/", true) || model.startsWith("openai/", true)
        GEMINI, KIMI -> false
    }
}

data class LLMConfiguration(
    val provider: LLMProvider,
    val apiKey: String,
    val model: String,
    val temperature: Double = 1.0,
)

data class LLMModel(val id: String, val name: String = id)
