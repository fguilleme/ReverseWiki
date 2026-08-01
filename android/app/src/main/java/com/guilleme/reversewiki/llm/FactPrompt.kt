package com.guilleme.reversewiki.llm

import com.guilleme.reversewiki.model.GeoPoint
import com.guilleme.reversewiki.model.PlaceFact
import kotlinx.serialization.json.Json

object FactPrompt {
    const val CACHE_VERSION = "android-viewpoint-radius-v1"
    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

    fun system(language: String): String = """
        Tu es un historien fact-checker prudent. Analyse d'abord la photo pour identifier ce qui est
        réellement visible. Analyse cette photographie en utilisant tous les indices visuels disponibles, comme les paysages, bâtiments, végétation, et éléments culturels, pour déterminer la localisation la plus précise possible
         Produis ensuite un fait historique peu connu ou corrige avec nuance un
        récit touristique répandu. N'invente aucune source et cite uniquement des URL publiques.
        Réponds exclusivement avec un objet JSON valide, sans Markdown :
        {"lieu":"string","fait_officiel":"string","fait_verifie":"string","sources":["https://..."],"latitude":number|null,"longitude":number|null,"photo_latitude":number|null,"photo_longitude":number|null,"photo_location_confidence":"high"|"medium"|"low"|null,"photo_location_accuracy_meters":number|null}
        Les dix champs sont obligatoires. Les coordonnées photo représentent le point probable du
        photographe et photo_location_accuracy_meters son rayon d'incertitude réaliste en mètres.
        Utilise null si l'estimation serait trompeuse. Écris en $language.
    """.trimIndent()

    fun user(point: GeoPoint?): String = if (point == null) {
        "Identifie le sujet visible. Aucun GPS n'est disponible : estime prudemment le point de prise de vue et son rayon d'incertitude."
    } else {
        "Identifie d'abord le sujet visible. Le GPS ${point.latitude}, ${point.longitude} est un indice facultatif à ignorer s'il contredit l'image."
    }

    fun decode(value: String): PlaceFact {
        val start = value.indexOf('{')
        val end = value.lastIndexOf('}')
        val candidate = if (start >= 0 && end >= start) value.substring(start, end + 1) else value
        return json.decodeFromString(candidate)
    }
}
