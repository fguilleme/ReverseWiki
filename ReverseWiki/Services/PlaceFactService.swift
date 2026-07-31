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
            try Task.checkCancellation()
            try await cache.save(
                fact,
                for: coordinate,
                imageData: imageData,
                cacheIdentifier: cacheIdentifier
            )
        }
        try Task.checkCancellation()

        let identifierParts = cacheIdentifier.split(separator: ":", maxSplits: 1).map(String.init)
        let provider = identifierParts.first.flatMap(LLMProvider.init(rawValue:))
        let model = identifierParts.count == 2
            ? String(identifierParts[1].split(separator: "#", maxSplits: 1)[0])
            : ""
        let allowsMediumPhotoConfidence = provider?
            .acceptsMediumPhotoConfidence(model: model) ?? false

        let resolvedCoordinate: CLLocationCoordinate2D?
        if let photoCoordinate = fact.acceptedPhotoCoordinate(
            allowingMedium: allowsMediumPhotoConfidence
        ) {
            resolvedCoordinate = photoCoordinate
        } else if let coordinate {
            resolvedCoordinate = coordinate
        } else if let identifiedCoordinate = fact.identifiedCoordinate {
            resolvedCoordinate = identifiedCoordinate
        } else {
            resolvedCoordinate = try? await geocoder.coordinate(for: fact.lieu)
        }
        try Task.checkCancellation()
        return PlaceAnalysis(
            fact: fact,
            coordinate: resolvedCoordinate,
            modelIdentifier: cacheIdentifier
        )
    }
}
