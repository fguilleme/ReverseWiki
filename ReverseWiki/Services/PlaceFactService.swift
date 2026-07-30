import CoreLocation

protocol PlaceFactProviding {
    func analyze(for coordinate: CLLocationCoordinate2D?, imageData: Data) async throws -> PlaceAnalysis
}

final class PlaceFactService: PlaceFactProviding {
    private let cache: FactCaching
    private let geocoder: ReverseGeocoding
    private let llm: LLMProviding

    init(cache: FactCaching, geocoder: ReverseGeocoding, llm: LLMProviding) {
        self.cache = cache
        self.geocoder = geocoder
        self.llm = llm
    }

    func analyze(for coordinate: CLLocationCoordinate2D?, imageData: Data) async throws -> PlaceAnalysis {
        let cacheIdentifier = await llm.cacheIdentifier()
        let fact: PlaceFact
        if let cached = try await cache.fact(
            for: coordinate,
            imageData: imageData,
            cacheIdentifier: cacheIdentifier
        ) {
            fact = cached
        } else {
            fact = try await llm.fetchFact(imageData: imageData, coordinate: coordinate)
            try await cache.save(
                fact,
                for: coordinate,
                imageData: imageData,
                cacheIdentifier: cacheIdentifier
            )
        }

        let resolvedCoordinate: CLLocationCoordinate2D?
        if let photoCoordinate = fact.photoCoordinate {
            resolvedCoordinate = photoCoordinate
        } else if let coordinate {
            resolvedCoordinate = coordinate
        } else if let identifiedCoordinate = fact.identifiedCoordinate {
            resolvedCoordinate = identifiedCoordinate
        } else {
            resolvedCoordinate = try? await geocoder.coordinate(for: fact.lieu)
        }
        return PlaceAnalysis(
            fact: fact,
            coordinate: resolvedCoordinate,
            modelIdentifier: cacheIdentifier
        )
    }
}
