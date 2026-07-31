package com.guilleme.reversewiki.location

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import androidx.core.content.ContextCompat
import com.guilleme.reversewiki.model.GeoPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.util.Locale
import kotlin.coroutines.resume

class DeviceLocation(private val context: Context) {
    private val manager = context.getSystemService(LocationManager::class.java)

    @Suppress("MissingPermission", "DEPRECATION")
    suspend fun current(): GeoPoint? {
        val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION)
        if (fine != PackageManager.PERMISSION_GRANTED && coarse != PackageManager.PERMISSION_GRANTED) return null
        return suspendCancellableCoroutine { continuation ->
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    manager.removeUpdates(this)
                    if (continuation.isActive) continuation.resume(GeoPoint(location.latitude, location.longitude))
                }
                override fun onProviderDisabled(provider: String) {
                    manager.removeUpdates(this)
                    if (continuation.isActive) continuation.resume(null)
                }
            }
            val provider = when {
                manager.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
                manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
                else -> null
            }
            if (provider == null) continuation.resume(null)
            else manager.requestSingleUpdate(provider, listener, null)
            continuation.invokeOnCancellation { manager.removeUpdates(listener) }
        }
    }
}

class ForwardGeocoder(private val context: Context) {
    @Suppress("DEPRECATION")
    suspend fun coordinate(place: String): GeoPoint? = withContext(Dispatchers.IO) {
        runCatching {
            Geocoder(context, Locale.getDefault()).getFromLocationName(place, 1)
                ?.firstOrNull()?.let { GeoPoint(it.latitude, it.longitude) }
        }.getOrNull()
    }
}
