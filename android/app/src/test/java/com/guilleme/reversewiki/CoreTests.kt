package com.guilleme.reversewiki

import com.guilleme.reversewiki.llm.FactPrompt
import com.guilleme.reversewiki.llm.LLMProvider
import com.guilleme.reversewiki.model.PhotoConfidence
import com.guilleme.reversewiki.model.accuracyMeters
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CoreTests {
    @Test
    fun structuredResponseDecodesViewpointAndRadius() {
        val fact = FactPrompt.decode(
            """{"lieu":"Tour Eiffel, France","fait_officiel":"Récit","fait_verifie":"Fait","sources":[],"latitude":48.8584,"longitude":2.2945,"photo_latitude":48.86,"photo_longitude":2.29,"photo_location_confidence":"medium","photo_location_accuracy_meters":350}""",
        )
        assertEquals(PhotoConfidence.MEDIUM, fact.photoConfidence)
        assertEquals(350.0, fact.accuracyMeters()!!, 0.0)
    }

    @Test
    fun confidenceThresholdDependsOnProvider() {
        assertTrue(LLMProvider.ANTHROPIC.acceptsMediumConfidence("claude-fable-5"))
        assertTrue(LLMProvider.OPENAI.acceptsMediumConfidence("gpt-5.6"))
        assertFalse(LLMProvider.GEMINI.acceptsMediumConfidence("gemini-2.5-flash"))
        assertTrue(LLMProvider.OPENROUTER.acceptsMediumConfidence("anthropic/claude-sonnet"))
        assertFalse(LLMProvider.OPENROUTER.acceptsMediumConfidence("google/gemini-flash"))
    }

    @Test
    fun radiusIsBounded() {
        val fact = FactPrompt.decode(
            """{"lieu":"Lieu","fait_officiel":"Récit","fait_verifie":"Fait","sources":[],"latitude":null,"longitude":null,"photo_latitude":1.0,"photo_longitude":2.0,"photo_location_confidence":"low","photo_location_accuracy_meters":999999}""",
        )
        assertEquals(100_000.0, fact.accuracyMeters()!!, 0.0)
    }
}
