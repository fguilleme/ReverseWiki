import Foundation

@MainActor
struct AppDependencies {
    let locationService: LocationService
    let placeFactService: PlaceFactProviding
    let cache: FactCaching
    let llmSettings: LLMSettings
    let modelCatalog: ModelCatalogProviding

    static func live() -> AppDependencies {
        let llmSettings = LLMSettings()
        let cache = CoreDataFactCache()
        return AppDependencies(
            locationService: LocationService(),
            placeFactService: PlaceFactService(
                cache: cache,
                geocoder: ReverseGeocodingService(),
                llm: ConfigurableLLMClient(settings: llmSettings)
            ),
            cache: cache,
            llmSettings: llmSettings,
            modelCatalog: ModelCatalogService()
        )
    }
}
