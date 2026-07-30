import CoreLocation
import Foundation

struct PlaceFact: Codable, Equatable, Sendable {
    let lieu: String
    let faitOfficiel: String
    let faitVerifie: String
    let sources: [String]
    let latitude: Double?
    let longitude: Double?
    let photoLatitude: Double?
    let photoLongitude: Double?

    init(
        lieu: String,
        faitOfficiel: String,
        faitVerifie: String,
        sources: [String],
        latitude: Double?,
        longitude: Double?,
        photoLatitude: Double? = nil,
        photoLongitude: Double? = nil
    ) {
        self.lieu = lieu
        self.faitOfficiel = faitOfficiel
        self.faitVerifie = faitVerifie
        self.sources = sources
        self.latitude = latitude
        self.longitude = longitude
        self.photoLatitude = photoLatitude
        self.photoLongitude = photoLongitude
    }

    enum CodingKeys: String, CodingKey {
        case lieu
        case faitOfficiel = "fait_officiel"
        case faitVerifie = "fait_verifie"
        case sources
        case latitude, longitude
        case photoLatitude = "photo_latitude"
        case photoLongitude = "photo_longitude"
    }

    var identifiedCoordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    var photoCoordinate: CLLocationCoordinate2D? {
        guard let photoLatitude, let photoLongitude else { return nil }
        let coordinate = CLLocationCoordinate2D(
            latitude: photoLatitude,
            longitude: photoLongitude
        )
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }
}

struct CapturedPlace: Sendable {
    let coordinate: CLLocationCoordinate2D
    let name: String
    let locality: String?
    let country: String?

    var promptDescription: String {
        [name, locality, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct CaptureResult: Identifiable {
    let id = UUID()
    let imageData: Data
    let coordinate: CLLocationCoordinate2D?
    let fact: PlaceFact
    let modelIdentifier: String?

    var modelDisplayName: String? {
        guard let modelIdentifier, !modelIdentifier.isEmpty else { return nil }
        let components = modelIdentifier.split(separator: ":", maxSplits: 1).map(String.init)
        guard components.count == 2 else { return modelIdentifier }
        let providerName = LLMProvider(rawValue: components[0])?.displayName ?? components[0]
        let modelName = components[1].split(separator: "#", maxSplits: 1).first
            .map(String.init) ?? components[1]
        return "\(providerName) · \(modelName)"
    }
}

struct PlaceAnalysis: Sendable {
    let fact: PlaceFact
    let coordinate: CLLocationCoordinate2D?
    let modelIdentifier: String
}

struct HistoryEntry: Identifiable, Sendable {
    let id: String
    let imageData: Data
    let date: Date
    let fact: PlaceFact
    let coordinate: CLLocationCoordinate2D?
    let modelIdentifier: String?

    var captureResult: CaptureResult {
        CaptureResult(
            imageData: imageData,
            coordinate: coordinate,
            fact: fact,
            modelIdentifier: modelIdentifier
        )
    }
}
