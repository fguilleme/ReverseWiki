package com.guilleme.reversewiki.ui

import android.content.Intent
import android.net.Uri
import android.graphics.Bitmap
import android.graphics.Color as AndroidColor
import android.view.MotionEvent
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.HelpOutline
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material.icons.filled.VpnKey
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.net.toUri
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.guilleme.reversewiki.llm.LLMProvider
import com.guilleme.reversewiki.export.ExportService
import com.guilleme.reversewiki.model.HistoryItem
import com.guilleme.reversewiki.model.PhotoConfidence
import com.guilleme.reversewiki.model.PlaceAnalysis
import com.guilleme.reversewiki.model.accuracyMeters
import com.guilleme.reversewiki.R
import org.maplibre.android.MapLibre
import org.maplibre.android.annotations.MarkerOptions
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapView
import org.maplibre.android.style.layers.FillLayer
import org.maplibre.android.style.layers.PropertyFactory.fillColor
import org.maplibre.android.style.layers.PropertyFactory.fillOutlineColor
import org.maplibre.android.style.sources.GeoJsonSource
import java.io.File
import java.text.DateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.PI
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

@Composable
fun ReverseWikiApp(viewModel: MainViewModel, onCamera: () -> Unit, onImport: () -> Unit) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val appContext = LocalContext.current
    val onboarding = remember {
        appContext.getSharedPreferences("onboarding", android.content.Context.MODE_PRIVATE)
    }
    var isFirstHelp by remember { mutableStateOf(!onboarding.getBoolean("help_seen", false)) }
    var showHelp by remember { mutableStateOf(isFirstHelp) }
    var showConfiguration by remember { mutableStateOf(false) }

    MaterialTheme(colorScheme = androidx.compose.material3.darkColorScheme(primary = Color(0xFF6C72FF))) {
        Scaffold(
            topBar = {
                AppTopBar(
                    showBack = state.analysis !is AnalysisState.Ready,
                    onBack = viewModel::reset,
                    onHelp = { showHelp = true },
                )
            },
            bottomBar = {
                NavigationBar {
                    NavigationBarItem(
                        selected = state.tab == MainTab.DISCOVER,
                        onClick = { viewModel.setTab(MainTab.DISCOVER) },
                        icon = { Icon(Icons.Default.CameraAlt, null) },
                        label = { Text("Découvrir") },
                    )
                    NavigationBarItem(
                        selected = state.tab == MainTab.HISTORY,
                        onClick = { viewModel.setTab(MainTab.HISTORY) },
                        icon = { Icon(Icons.Default.History, null) },
                        label = { Text("Historique") },
                    )
                }
            },
        ) { padding ->
            Box(Modifier.fillMaxSize().padding(padding)) {
                if (state.tab == MainTab.HISTORY) {
                    HistoryScreen(state.history, viewModel::openHistory, viewModel::deleteHistory, viewModel::clearCache)
                } else when (val analysis = state.analysis) {
                    AnalysisState.Ready -> DiscoverScreen(
                        state, onCamera, onImport, viewModel::setProvider, viewModel::setModel,
                        { showConfiguration = true }, viewModel::refreshModels,
                    )
                    AnalysisState.Processing -> ProcessingScreen(viewModel::cancelAnalysis)
                    is AnalysisState.Result -> ResultScreen(analysis.analysis, analysis.imagePath, viewModel::reset)
                    is AnalysisState.Failed -> ErrorScreen(analysis.message, viewModel::reset)
                }
            }
        }
        if (showHelp) HelpDialog(isFirstLaunch = isFirstHelp) {
            onboarding.edit().putBoolean("help_seen", true).apply()
            isFirstHelp = false
            showHelp = false
        }
        if (showConfiguration) ConfigurationDialog(
            provider = state.provider,
            initialKey = viewModel.apiKey(),
            initialTemperature = viewModel.temperature(),
            onDismiss = { showConfiguration = false },
            onSave = { key, temperature ->
                viewModel.saveConfiguration(key, temperature)
                showConfiguration = false
            },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AppTopBar(showBack: Boolean, onBack: () -> Unit, onHelp: () -> Unit) {
    TopAppBar(
        title = { Text("Reverse Wiki", modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center) },
        navigationIcon = { if (showBack) TextButton(onClick = onBack) { Text("Retour") } },
        actions = {
            IconButton(onClick = onHelp) {
                Icon(Icons.AutoMirrored.Filled.HelpOutline, "Aide")
            }
        },
    )
}

@Composable
private fun DiscoverScreen(
    state: MainUiState,
    onCamera: () -> Unit,
    onImport: () -> Unit,
    onProvider: (LLMProvider) -> Unit,
    onModel: (String) -> Unit,
    onConfigure: () -> Unit,
    onRefreshModels: () -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item { Spacer(Modifier.height(16.dp)) }
        item { Icon(Icons.Default.Public, null, Modifier.size(72.dp), tint = MaterialTheme.colorScheme.primary) }
        item {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Regardez derrière le récit", fontSize = 24.sp, fontWeight = FontWeight.Bold)
                Text(
                    "Photographiez un lieu pour découvrir une histoire vérifiée et sourcée.",
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        item { AISettingsCard(state, onProvider, onModel, onConfigure, onRefreshModels) }
        item {
            Button(onClick = onCamera, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Default.CameraAlt, null); Text("  Prendre une photo")
            }
        }
        item {
            FilledTonalButton(onClick = onImport, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Default.PhotoLibrary, null); Text("  Importer une photo")
            }
        }
    }
}

@Composable
private fun AISettingsCard(
    state: MainUiState,
    onProvider: (LLMProvider) -> Unit,
    onModel: (String) -> Unit,
    onConfigure: () -> Unit,
    onRefreshModels: () -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    var providerMenu by remember { mutableStateOf(false) }
    var modelMenu by remember { mutableStateOf(false) }
    val selectedModelName = state.models.firstOrNull { it.id == state.model }?.name
        ?: state.model.ifEmpty { stringResource(R.string.choose_model) }
    Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(18.dp)) {
        Column(Modifier.padding(2.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            if (!expanded) {
                Row(
                    Modifier.fillMaxWidth().clickable { expanded = true }.padding(vertical = 2.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(
                        Icons.Default.AutoAwesome,
                        null,
                        Modifier.size(19.dp),
                        tint = MaterialTheme.colorScheme.primary,
                    )
                    Text(
                        selectedModelName,
                        modifier = Modifier.weight(1f),
                        maxLines = 1,
                        style = MaterialTheme.typography.bodyLarge,
                    )
                    Icon(
                        Icons.Default.KeyboardArrowDown,
                        stringResource(R.string.expand_ai_settings),
                        Modifier.size(24.dp),
                    )
                }
            } else {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Default.AutoAwesome,
                        null,
                        Modifier.size(19.dp),
                        tint = MaterialTheme.colorScheme.primary,
                    )
                    Text(
                        stringResource(R.string.ai_title),
                        fontWeight = FontWeight.Bold,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f).padding(start = 7.dp),
                    )
                    IconButton(onClick = onConfigure, modifier = Modifier.size(32.dp)) {
                        Icon(
                            Icons.Default.VpnKey,
                            stringResource(R.string.configure_api_key),
                            Modifier.size(18.dp),
                        )
                    }
                    IconButton(onClick = { expanded = false }, modifier = Modifier.size(32.dp)) {
                        Icon(
                            Icons.Default.KeyboardArrowUp,
                            stringResource(R.string.collapse_ai_settings),
                            Modifier.size(19.dp),
                        )
                    }
                }

                Box(Modifier.fillMaxWidth()) {
                    AISelectionRow(
                        label = stringResource(R.string.provider),
                        value = state.provider.displayName,
                        enabled = true,
                        onClick = { providerMenu = true },
                    )
                    DropdownMenu(providerMenu, { providerMenu = false }) {
                        LLMProvider.entries.forEach { provider ->
                            DropdownMenuItem(
                                text = { Text(provider.displayName) },
                                onClick = { providerMenu = false; onProvider(provider) },
                            )
                        }
                    }
                }

                Box(Modifier.fillMaxWidth()) {
                    AISelectionRow(
                        label = stringResource(R.string.model),
                        value = selectedModelName,
                        enabled = !state.modelLoading && state.models.isNotEmpty(),
                        onClick = { modelMenu = true },
                    )
                    DropdownMenu(modelMenu, { modelMenu = false }) {
                        state.models.forEach { model ->
                            DropdownMenuItem(text = { Text(model.name) }, onClick = {
                                modelMenu = false; onModel(model.id)
                            })
                        }
                    }
                }

                when {
                    state.modelLoading -> Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                        Text(stringResource(R.string.loading_models), style = MaterialTheme.typography.labelMedium)
                    }
                    state.modelError != null -> Row(verticalAlignment = Alignment.Top) {
                        Text(
                            state.modelError,
                            modifier = Modifier.weight(1f),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        TextButton(onClick = onConfigure) { Text(stringResource(R.string.configure)) }
                    }
                    else -> TextButton(onClick = onRefreshModels) {
                        Icon(Icons.Default.Refresh, null, Modifier.size(18.dp))
                        Text(stringResource(R.string.refresh_models), modifier = Modifier.padding(start = 6.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun AISelectionRow(label: String, value: String, enabled: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable(enabled = enabled, onClick = onClick).padding(vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodySmall)
        Text(
            value,
            maxLines = 1,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1.4f),
            textAlign = TextAlign.End,
        )
        Icon(
            Icons.Default.SwapVert,
            contentDescription = null,
            modifier = Modifier.padding(start = 6.dp).size(16.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ProcessingScreen(onCancel: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        CircularProgressIndicator()
        Spacer(Modifier.height(20.dp))
        Text("Identification et vérification…", fontWeight = FontWeight.Bold)
        Text("Localisation du lieu et vérification des sources.", textAlign = TextAlign.Center)
        Spacer(Modifier.height(20.dp))
        OutlinedButton(onClick = onCancel) { Text("Annuler") }
    }
}

@Composable
private fun ResultScreen(analysis: PlaceAnalysis, imagePath: String, onRestart: () -> Unit) {
    val fact = analysis.fact
    val providerName = analysis.modelIdentifier.substringBefore(':').replaceFirstChar(Char::uppercase)
    val modelName = analysis.modelIdentifier.substringAfter(':').substringBefore('#')
    val acceptedPhoto = fact.photoConfidence == PhotoConfidence.HIGH ||
        (fact.photoConfidence == PhotoConfidence.MEDIUM &&
            runCatching { LLMProvider.valueOf(providerName.uppercase()) }.getOrNull()
                ?.acceptsMediumConfidence(modelName) == true)
    var mapBitmap by remember { mutableStateOf<Bitmap?>(null) }
    val context = LocalContext.current
    LazyColumn(
        Modifier.fillMaxSize().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            AsyncImage(
                model = File(imagePath), contentDescription = fact.lieu,
                modifier = Modifier.fillMaxWidth().height(280.dp).clip(RoundedCornerShape(24.dp)),
                contentScale = ContentScale.Crop,
            )
        }
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        fact.lieu,
                        fontSize = 21.sp,
                        lineHeight = 24.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        fact.verifiedFact,
                        fontSize = 15.sp,
                        lineHeight = 21.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                    HorizontalDivider()
                    Text(
                        "Le récit courant",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(fact.officialFact, fontSize = 14.sp, lineHeight = 20.sp)
                }
            }
        }
        item { Text("$providerName · $modelName", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        analysis.mapPoint?.let { point ->
            item {
                ResultMap(
                    point.latitude,
                    point.longitude,
                    if (acceptedPhoto) fact.accuracyMeters() else null,
                    onSnapshot = { mapBitmap = it },
                )
            }
        }
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Sources", fontWeight = FontWeight.Bold)
                val context = LocalContext.current
                fact.sources.forEach { source ->
                    TextButton(onClick = {
                        context.startActivity(Intent(Intent.ACTION_VIEW, source.toUri()))
                    }) { Text(source) }
                }
            }
        }
        item {
            OutlinedButton(
                onClick = { ExportService.sharePostcard(context, imagePath, analysis) },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Partager la carte postale") }
        }
        item {
            OutlinedButton(
                onClick = { ExportService.sharePdf(context, imagePath, analysis, mapBitmap) },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Partager le document PDF") }
        }
        item { Button(onClick = onRestart, Modifier.fillMaxWidth()) { Text("Analyser un autre lieu") } }
        item { Spacer(Modifier.height(16.dp)) }
    }
}

@Composable
private fun ResultMap(
    latitude: Double,
    longitude: Double,
    radius: Double?,
    onSnapshot: (Bitmap) -> Unit,
) {
    val context = LocalContext.current
    val latestSnapshot by rememberUpdatedState(onSnapshot)
    val mapView = remember(latitude, longitude, radius) {
        MapLibre.getInstance(context)
        MapView(context).also { view ->
            view.onCreate(null)
            view.onStart()
            view.onResume()
            view.setOnTouchListener { touchedView, event ->
                val keepGestureInMap = when (event.actionMasked) {
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> false
                    else -> true
                }
                touchedView.parent?.requestDisallowInterceptTouchEvent(keepGestureInMap)
                false
            }
            view.getMapAsync { map ->
                val point = LatLng(latitude, longitude)
                map.cameraPosition = CameraPosition.Builder()
                    .target(point)
                    .zoom(mapZoom(radius))
                    .build()
                map.setStyle(OPEN_MAP_STYLE) { style ->
                    radius?.let {
                        style.addSource(GeoJsonSource(ACCURACY_SOURCE, accuracyPolygon(latitude, longitude, it)))
                        style.addLayer(
                            FillLayer(ACCURACY_LAYER, ACCURACY_SOURCE).withProperties(
                                fillColor(AndroidColor.argb(55, 33, 150, 243)),
                                fillOutlineColor(AndroidColor.rgb(33, 150, 243)),
                            )
                        )
                    }
                    map.clear()
                    map.addMarker(MarkerOptions().position(point).title("Position"))
                    view.postDelayed({ map.snapshot { bitmap -> latestSnapshot(bitmap) } }, 1_500)
                }
            }
        }
    }
    DisposableEffect(mapView) {
        onDispose {
            mapView.onPause()
            mapView.onStop()
            mapView.onDestroy()
        }
    }
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (radius != null) {
            Text("Point de prise de vue estimé", fontWeight = FontWeight.SemiBold)
            Text("Rayon d’incertitude : environ ${formatDistance(radius)}")
        }
        AndroidView(
            factory = { mapView },
            modifier = Modifier.fillMaxWidth().height(240.dp),
        )
        Text(
            "© OpenStreetMap contributors · OpenFreeMap",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

private const val OPEN_MAP_STYLE = "https://tiles.openfreemap.org/styles/liberty"
private const val ACCURACY_SOURCE = "reversewiki-accuracy-source"
private const val ACCURACY_LAYER = "reversewiki-accuracy-layer"

private fun mapZoom(radius: Double?): Double = when {
    radius == null -> 11.0
    radius > 50_000 -> 6.0
    radius > 10_000 -> 8.0
    radius > 2_000 -> 10.0
    else -> 13.0
}

private fun accuracyPolygon(latitude: Double, longitude: Double, radiusMeters: Double): String {
    val earthRadius = 6_371_000.0
    val angularDistance = radiusMeters / earthRadius
    val latitudeRadians = Math.toRadians(latitude)
    val longitudeRadians = Math.toRadians(longitude)
    val coordinates = (0..64).joinToString(",") { index ->
        val bearing = 2.0 * PI * index / 64.0
        val targetLatitude = asin(
            sin(latitudeRadians) * cos(angularDistance) +
                cos(latitudeRadians) * sin(angularDistance) * cos(bearing)
        )
        val targetLongitude = longitudeRadians + atan2(
            sin(bearing) * sin(angularDistance) * cos(latitudeRadians),
            cos(angularDistance) - sin(latitudeRadians) * sin(targetLatitude),
        )
        String.format(Locale.US, "[%f,%f]", Math.toDegrees(targetLongitude), Math.toDegrees(targetLatitude))
    }
    return """{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[$coordinates]]}}"""
}

private fun formatDistance(meters: Double): String = if (meters >= 1_000) {
    "%.1f km".format(meters / 1_000)
} else "%.0f m".format(meters)

@Composable
private fun HistoryScreen(
    history: List<HistoryItem>,
    onOpen: (HistoryItem) -> Unit,
    onDelete: (HistoryItem) -> Unit,
    onClearCache: () -> Unit,
) {
    if (history.isEmpty()) {
        Column(
            Modifier.fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text("Aucune analyse enregistrée")
            TextButton(onClick = onClearCache) { Text(stringResource(R.string.clear_cache)) }
        }
        return
    }
    LazyColumn(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            TextButton(onClick = onClearCache, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.clear_cache))
            }
        }
        items(history, key = { it.id }) { item ->
            Card(onClick = { onOpen(item) }, modifier = Modifier.fillMaxWidth()) {
                Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    AsyncImage(
                        File(item.imagePath),
                        null,
                        Modifier.size(64.dp).clip(RoundedCornerShape(12.dp)),
                        contentScale = ContentScale.Crop,
                    )
                    Column(Modifier.weight(1f).padding(horizontal = 10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            item.fact.lieu,
                            fontSize = 15.sp,
                            lineHeight = 18.sp,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 3,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Text(
                            DateFormat.getDateTimeInstance().format(Date(item.createdAt)),
                            fontSize = 12.sp,
                            lineHeight = 15.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    IconButton(onClick = { onDelete(item) }, modifier = Modifier.size(44.dp)) {
                        Icon(
                            Icons.Default.Delete,
                            "Supprimer",
                            modifier = Modifier.size(27.dp),
                            tint = MaterialTheme.colorScheme.error,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ErrorScreen(message: String, onRetry: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("Échec de l’analyse", fontSize = 24.sp, fontWeight = FontWeight.Bold)
        Text(message, textAlign = TextAlign.Center)
        Button(onClick = onRetry) { Text("Réessayer") }
    }
}

@Composable
private fun ConfigurationDialog(
    provider: LLMProvider,
    initialKey: String,
    initialTemperature: Double,
    onDismiss: () -> Unit,
    onSave: (String, Double) -> Unit,
) {
    var key by remember(provider) { mutableStateOf(initialKey) }
    var temperature by remember(provider) { mutableDoubleStateOf(initialTemperature) }
    val context = LocalContext.current
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(provider.displayName) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(key, { key = it }, label = { Text("Clé API") }, singleLine = true)
                Text("Température : ${"%.1f".format(temperature)}")
                Slider(temperature.toFloat(), { temperature = it.toDouble() }, valueRange = 0f..2f, steps = 19)
                provider.keyUrl?.let { url ->
                    TextButton(onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }) {
                        Text("Créer une clé API")
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = { onSave(key, temperature) }) { Text("Enregistrer") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Annuler") } },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HelpDialog(isFirstLaunch: Boolean, onDismiss: () -> Unit) {
    Dialog(
        onDismissRequest = { if (!isFirstLaunch) onDismiss() },
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            dismissOnBackPress = !isFirstLaunch,
            dismissOnClickOutside = false,
        ),
    ) {
        Surface(Modifier.fillMaxSize()) {
            Scaffold(
                topBar = {
                    TopAppBar(
                        title = { Text(stringResource(R.string.help_title)) },
                        actions = {
                            if (!isFirstLaunch) {
                                IconButton(onClick = onDismiss) {
                                    Icon(Icons.Default.Close, stringResource(R.string.close))
                                }
                            }
                        },
                    )
                },
                bottomBar = {
                    Surface(tonalElevation = 3.dp) {
                        Button(
                            onClick = onDismiss,
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 12.dp),
                        ) {
                            Text(stringResource(if (isFirstLaunch) R.string.start else R.string.close))
                        }
                    }
                },
            ) { padding ->
                LazyColumn(
                    modifier = Modifier.fillMaxSize().padding(padding).padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    item {
                        Icon(
                            Icons.Default.Public,
                            contentDescription = null,
                            modifier = Modifier.size(72.dp),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                    item {
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(
                                stringResource(R.string.help_welcome),
                                fontSize = 32.sp,
                                fontWeight = FontWeight.Bold,
                                textAlign = TextAlign.Center,
                            )
                            Text(
                                stringResource(R.string.help_subtitle),
                                style = MaterialTheme.typography.titleMedium,
                                textAlign = TextAlign.Center,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                    item { HelpRow(Icons.Default.CameraAlt, R.string.help_photo_title, R.string.help_photo_description) }
                    item { HelpRow(Icons.Default.LocationOn, R.string.help_location_title, R.string.help_location_description) }
                    item { HelpRow(Icons.Default.AutoAwesome, R.string.help_model_title, R.string.help_model_description) }
                    item { ModelChoiceAdvice() }
                    item { HelpRow(Icons.Default.CheckCircle, R.string.help_sources_title, R.string.help_sources_description) }
                    item { HelpRow(Icons.Default.History, R.string.help_history_title, R.string.help_history_description) }
                }
            }
        }
    }
}

@Composable
private fun ModelChoiceAdvice() {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Default.Info, null, tint = MaterialTheme.colorScheme.primary)
                Text(stringResource(R.string.help_model_advice_title), fontWeight = FontWeight.Bold)
            }
            Text(stringResource(R.string.help_model_advice_shared))
            Text(stringResource(R.string.help_model_advice_key), fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun HelpRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: Int,
    description: Int,
) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        Icon(icon, null, modifier = Modifier.size(32.dp), tint = MaterialTheme.colorScheme.primary)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(stringResource(title), fontWeight = FontWeight.Bold)
            Text(stringResource(description), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
