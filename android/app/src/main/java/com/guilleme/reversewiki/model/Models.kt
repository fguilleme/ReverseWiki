package com.guilleme.reversewiki.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class PlaceFact(
    val lieu: String,
    @SerialName("fait_officiel") val officialFact: String,
    @SerialName("fait_verifie") val verifiedFact: String,
    val sources: List<String> = emptyList(),
    val latitude: Double? = null,
    val longitude: Double? = null,
    @SerialName("photo_latitude") val photoLatitude: Double? = null,
    @SerialName("photo_longitude") val photoLongitude: Double? = null,
    @SerialName("photo_location_confidence") val photoConfidence: PhotoConfidence? = null,
    @SerialName("photo_location_accuracy_meters") val photoAccuracyMeters: Double? = null,
)

@Serializable
enum class PhotoConfidence {
    @SerialName("high") HIGH,
    @SerialName("medium") MEDIUM,
    @SerialName("low") LOW,
}

data class GeoPoint(val latitude: Double, val longitude: Double) {
    fun isValid(): Boolean = latitude in -90.0..90.0 && longitude in -180.0..180.0
}

data class PlaceAnalysis(
    val fact: PlaceFact,
    val mapPoint: GeoPoint?,
    val modelIdentifier: String,
    val cacheKey: String? = null,
)

data class HistoryItem(
    val id: Long,
    val createdAt: Long,
    val imagePath: String,
    val fact: PlaceFact,
    val mapPoint: GeoPoint?,
    val modelIdentifier: String,
    val cacheKey: String?,
)

fun PlaceFact.identifiedPoint(): GeoPoint? = latitude?.let { lat ->
    longitude?.let { lon -> GeoPoint(lat, lon).takeIf(GeoPoint::isValid) }
}

fun PlaceFact.photoPoint(): GeoPoint? = photoLatitude?.let { lat ->
    photoLongitude?.let { lon -> GeoPoint(lat, lon).takeIf(GeoPoint::isValid) }
}

fun PlaceFact.accuracyMeters(): Double? = photoAccuracyMeters
    ?.takeIf { it.isFinite() && it > 0 }
    ?.coerceIn(25.0, 100_000.0)
