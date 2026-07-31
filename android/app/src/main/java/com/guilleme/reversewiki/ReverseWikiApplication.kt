package com.guilleme.reversewiki

import android.app.Application
import com.guilleme.reversewiki.data.LocalStore
import com.guilleme.reversewiki.data.PlaceRepository
import com.guilleme.reversewiki.llm.LLMSettings
import com.guilleme.reversewiki.llm.ModelCatalog
import com.guilleme.reversewiki.location.DeviceLocation

class ReverseWikiApplication : Application() {
    val store by lazy { LocalStore(this) }
    val settings by lazy { LLMSettings(this) }
    val repository by lazy { PlaceRepository(this, store) }
    val location by lazy { DeviceLocation(this) }
    val modelCatalog by lazy { ModelCatalog() }
}
