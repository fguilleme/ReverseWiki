package com.guilleme.reversewiki.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.guilleme.reversewiki.model.GeoPoint
import com.guilleme.reversewiki.model.HistoryItem
import com.guilleme.reversewiki.model.PlaceFact
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.security.MessageDigest

class LocalStore(context: Context) : SQLiteOpenHelper(context, "reversewiki.db", null, 1) {
    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE cache(cache_key TEXT PRIMARY KEY, fact_json TEXT NOT NULL)")
        db.execSQL(
            """CREATE TABLE history(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at INTEGER NOT NULL,
                image_path TEXT NOT NULL,
                fact_json TEXT NOT NULL,
                latitude REAL,
                longitude REAL,
                model_identifier TEXT NOT NULL
            )""".trimIndent(),
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    fun cachedFact(key: String): PlaceFact? = readableDatabase.query(
        "cache", arrayOf("fact_json"), "cache_key=?", arrayOf(key), null, null, null,
    ).use { cursor ->
        if (!cursor.moveToFirst()) null
        else runCatching { json.decodeFromString<PlaceFact>(cursor.getString(0)) }.getOrNull()
    }

    fun saveCache(key: String, fact: PlaceFact) {
        writableDatabase.insertWithOnConflict(
            "cache",
            null,
            ContentValues().apply {
                put("cache_key", key)
                put("fact_json", json.encodeToString(fact))
            },
            SQLiteDatabase.CONFLICT_REPLACE,
        )
    }

    fun clearCache() = writableDatabase.delete("cache", null, null)

    fun addHistory(imagePath: String, fact: PlaceFact, point: GeoPoint?, modelIdentifier: String) {
        writableDatabase.insert("history", null, ContentValues().apply {
            put("created_at", System.currentTimeMillis())
            put("image_path", imagePath)
            put("fact_json", json.encodeToString(fact))
            point?.let { put("latitude", it.latitude); put("longitude", it.longitude) }
            put("model_identifier", modelIdentifier)
        })
    }

    fun history(): List<HistoryItem> = readableDatabase.query(
        "history", null, null, null, null, null, "created_at DESC",
    ).use { cursor ->
        buildList {
            while (cursor.moveToNext()) {
                runCatching {
                    val latitudeIndex = cursor.getColumnIndexOrThrow("latitude")
                    val longitudeIndex = cursor.getColumnIndexOrThrow("longitude")
                    HistoryItem(
                        id = cursor.getLong(cursor.getColumnIndexOrThrow("id")),
                        createdAt = cursor.getLong(cursor.getColumnIndexOrThrow("created_at")),
                        imagePath = cursor.getString(cursor.getColumnIndexOrThrow("image_path")),
                        fact = json.decodeFromString(cursor.getString(cursor.getColumnIndexOrThrow("fact_json"))),
                        mapPoint = if (cursor.isNull(latitudeIndex) || cursor.isNull(longitudeIndex)) null
                        else GeoPoint(cursor.getDouble(latitudeIndex), cursor.getDouble(longitudeIndex)),
                        modelIdentifier = cursor.getString(cursor.getColumnIndexOrThrow("model_identifier")),
                    )
                }.getOrNull()?.let(::add)
            }
        }
    }

    fun deleteHistory(id: Long) = writableDatabase.delete("history", "id=?", arrayOf(id.toString()))

    companion object {
        fun cacheKey(image: ByteArray, point: GeoPoint?, model: String): String {
            val digest = MessageDigest.getInstance("SHA-256").digest(image)
                .joinToString("") { "%02x".format(it) }
            val coordinate = point?.let { "%.4f,%.4f".format(it.latitude, it.longitude) } ?: "none"
            return "$model:$coordinate:$digest"
        }
    }
}
