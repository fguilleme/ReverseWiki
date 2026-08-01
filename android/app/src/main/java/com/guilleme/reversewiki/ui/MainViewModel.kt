package com.guilleme.reversewiki.ui

import android.app.Application
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.guilleme.reversewiki.ReverseWikiApplication
import com.guilleme.reversewiki.llm.LLMModel
import com.guilleme.reversewiki.llm.LLMProvider
import com.guilleme.reversewiki.model.HistoryItem
import com.guilleme.reversewiki.model.PlaceAnalysis
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

enum class MainTab { DISCOVER, HISTORY }

sealed interface AnalysisState {
    data object Ready : AnalysisState
    data object Processing : AnalysisState
    data class Result(val analysis: PlaceAnalysis, val imagePath: String) : AnalysisState
    data class Failed(val message: String) : AnalysisState
}

data class MainUiState(
    val tab: MainTab = MainTab.DISCOVER,
    val analysis: AnalysisState = AnalysisState.Ready,
    val provider: LLMProvider = LLMProvider.GEMINI,
    val model: String = LLMProvider.GEMINI.defaultModel,
    val models: List<LLMModel> = emptyList(),
    val modelLoading: Boolean = false,
    val modelError: String? = null,
    val keyPresent: Boolean = false,
    val history: List<HistoryItem> = emptyList(),
)

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val app = application as ReverseWikiApplication
    private val _uiState = MutableStateFlow(
        MainUiState(
            provider = app.settings.provider,
            model = app.settings.model(),
            keyPresent = app.settings.apiKey().isNotBlank(),
        ),
    )
    val uiState: StateFlow<MainUiState> = _uiState.asStateFlow()
    private var analysisJob: Job? = null

    init {
        refreshHistory()
        if (_uiState.value.keyPresent) refreshModels()
    }

    fun setTab(tab: MainTab) {
        _uiState.update { it.copy(tab = tab) }
        if (tab == MainTab.HISTORY) refreshHistory()
    }

    fun setProvider(provider: LLMProvider) {
        app.settings.provider = provider
        _uiState.update {
            it.copy(
                provider = provider,
                model = app.settings.model(provider),
                models = emptyList(),
                keyPresent = app.settings.apiKey(provider).isNotBlank(),
                modelError = null,
            )
        }
        if (_uiState.value.keyPresent) refreshModels()
    }

    fun setModel(model: String) {
        app.settings.setModel(_uiState.value.provider, model)
        _uiState.update { it.copy(model = model) }
    }

    fun saveConfiguration(key: String, temperature: Double) {
        val state = _uiState.value
        app.settings.setApiKey(state.provider, key)
        app.settings.setTemperature(state.provider, state.model, temperature)
        _uiState.update { it.copy(keyPresent = key.isNotBlank()) }
        refreshModels()
    }

    fun apiKey(): String = app.settings.apiKey(_uiState.value.provider)
    fun temperature(): Double = app.settings.temperature(_uiState.value.provider, _uiState.value.model)

    fun refreshModels() {
        val provider = _uiState.value.provider
        val key = app.settings.apiKey(provider)
        if (key.isBlank()) return
        viewModelScope.launch {
            _uiState.update { it.copy(modelLoading = true, modelError = null) }
            runCatching { app.modelCatalog.models(provider, key) }
                .onSuccess { models ->
                    if (_uiState.value.provider != provider) return@onSuccess
                    val selected = _uiState.value.model.takeIf { current -> models.any { it.id == current } }
                        ?: models.firstOrNull()?.id.orEmpty()
                    if (selected.isNotEmpty()) app.settings.setModel(provider, selected)
                    _uiState.update { it.copy(models = models, model = selected, modelLoading = false) }
                }
                .onFailure { error ->
                    _uiState.update { it.copy(modelLoading = false, modelError = error.message) }
                }
        }
    }

    fun analyze(bytes: ByteArray, useCurrentLocation: Boolean) {
        analysisJob?.cancel()
        _uiState.update { it.copy(analysis = AnalysisState.Processing, tab = MainTab.DISCOVER) }
        analysisJob = viewModelScope.launch {
            runCatching {
                val normalized = withContext(Dispatchers.Default) { normalizeJpeg(bytes) }
                val point = if (useCurrentLocation) app.location.current() else null
                val analysis = app.repository.analyze(normalized, point, app.settings.configuration())
                val path = persistImage(normalized)
                withContext(Dispatchers.IO) {
                    app.store.addHistory(
                        path,
                        analysis.fact,
                        analysis.mapPoint,
                        analysis.modelIdentifier,
                        analysis.cacheKey,
                    )
                }
                analysis to path
            }.onSuccess { (analysis, path) ->
                _uiState.update { it.copy(analysis = AnalysisState.Result(analysis, path)) }
                refreshHistory()
            }.onFailure { error ->
                if (error is kotlinx.coroutines.CancellationException) return@onFailure
                _uiState.update { it.copy(analysis = AnalysisState.Failed(error.message ?: "Erreur inconnue")) }
            }
        }
    }

    fun cancelAnalysis() {
        analysisJob?.cancel()
        analysisJob = null
        _uiState.update { it.copy(analysis = AnalysisState.Ready) }
    }

    fun reset() = cancelAnalysis()

    fun openHistory(item: HistoryItem) {
        _uiState.update {
            it.copy(
                tab = MainTab.DISCOVER,
                analysis = AnalysisState.Result(
                    PlaceAnalysis(item.fact, item.mapPoint, item.modelIdentifier, item.cacheKey),
                    item.imagePath,
                ),
            )
        }
    }

    fun deleteHistory(item: HistoryItem) {
        viewModelScope.launch(Dispatchers.IO) {
            app.store.deleteHistory(item.id)
            File(item.imagePath).delete()
            withContext(Dispatchers.Main) { refreshHistory() }
        }
    }

    fun clearCache() = viewModelScope.launch(Dispatchers.IO) {
        app.store.clearAll().forEach { File(it).delete() }
        withContext(Dispatchers.Main) { refreshHistory() }
    }

    private fun refreshHistory() {
        viewModelScope.launch {
            val history = withContext(Dispatchers.IO) { app.store.history() }
            _uiState.update { it.copy(history = history) }
        }
    }

    private suspend fun persistImage(bytes: ByteArray): String = withContext(Dispatchers.IO) {
        val directory = File(getApplication<Application>().filesDir, "history").apply { mkdirs() }
        File(directory, "${System.currentTimeMillis()}.jpg").also { it.writeBytes(bytes) }.absolutePath
    }

    private fun normalizeJpeg(bytes: ByteArray): ByteArray {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 1_600) sample *= 2
        val bitmap = BitmapFactory.decodeByteArray(
            bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: error("Image illisible")
        val scale = minOf(1f, 1_600f / maxOf(bitmap.width, bitmap.height))
        val resized = if (scale < 1f) Bitmap.createScaledBitmap(
            bitmap, (bitmap.width * scale).toInt(), (bitmap.height * scale).toInt(), true,
        ) else bitmap
        return java.io.ByteArrayOutputStream().use { stream ->
            resized.compress(Bitmap.CompressFormat.JPEG, 85, stream)
            if (resized !== bitmap) resized.recycle()
            bitmap.recycle()
            stream.toByteArray()
        }
    }
}
