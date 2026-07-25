import Foundation

@MainActor
struct AppDependencies {
    let locationService: LocationService
    let placeFactService: PlaceFactProviding
    let cache: FactCaching

    static func live() -> AppDependencies {
        let configuration = LLMConfiguration.fromBundle()
        let cache = CoreDataFactCache()
        return AppDependencies(
            locationService: LocationService(),
            placeFactService: PlaceFactService(
                cache: cache,
                geocoder: ReverseGeocodingService(),
                llm: LLMClientFactory.make(configuration: configuration)
            ),
            cache: cache
        )
    }
}
