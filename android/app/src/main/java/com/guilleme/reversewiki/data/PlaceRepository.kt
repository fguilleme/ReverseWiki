package com.guilleme.reversewiki.data

import android.content.Context
import com.guilleme.reversewiki.llm.FactPrompt
import com.guilleme.reversewiki.llm.LLMConfiguration
import com.guilleme.reversewiki.llm.RemoteLLMClient
import com.guilleme.reversewiki.location.ForwardGeocoder
import com.guilleme.reversewiki.model.GeoPoint
import com.guilleme.reversewiki.model.PhotoConfidence
import com.guilleme.reversewiki.model.PlaceAnalysis
import com.guilleme.reversewiki.model.identifiedPoint
import com.guilleme.reversewiki.model.photoPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import kotlin.coroutines.coroutineContext

class PlaceRepository(
    context: Context,
    private val store: LocalStore,
    private val geocoder: ForwardGeocoder = ForwardGeocoder(context),
) {
    suspend fun analyze(
        image: ByteArray,
        location: GeoPoint?,
        configuration: LLMConfiguration,
    ): PlaceAnalysis {
        val identifier = "${configuration.provider.name.lowercase()}:${configuration.model}#${FactPrompt.CACHE_VERSION}"
        val key = LocalStore.cacheKey(image, location, identifier)
        val fact = withContext(Dispatchers.IO) { store.cachedFact(key) }
            ?: RemoteLLMClient(configuration).fetchFact(image, location).also {
                coroutineContext.ensureActive()
                withContext(Dispatchers.IO) { store.saveCache(key, it) }
            }
        coroutineContext.ensureActive()
        val acceptsMedium = configuration.provider.acceptsMediumConfidence(configuration.model)
        val photoPoint = fact.photoPoint()?.takeIf {
            fact.photoConfidence == PhotoConfidence.HIGH ||
                (acceptsMedium && fact.photoConfidence == PhotoConfidence.MEDIUM)
        }
        val resolved = photoPoint ?: location ?: fact.identifiedPoint() ?: geocoder.coordinate(fact.lieu)
        coroutineContext.ensureActive()
        return PlaceAnalysis(fact, resolved, identifier, key)
    }
}
