import CoreLocation
import Foundation

enum PhotoLocationConfidence: String, Codable, Equatable, Sendable {
    case high
    case medium
    case low

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch value {
        case "high", "élevée", "elevee", "alta", "hoch":
            self = .high
        case "medium", "moyenne", "moderate", "moderate confidence", "media", "mittel":
            self = .medium
        default:
            self = .low
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct PlaceFact: Codable, Equatable, Sendable {
    let lieu: String
    let faitOfficiel: String
    let faitVerifie: String
    let sources: [String]
    let latitude: Double?
    let longitude: Double?
    let photoLatitude: Double?
    let photoLongitude: Double?
    let photoLocationConfidence: PhotoLocationConfidence?
    let photoLocationAccuracyMeters: Double?

    init(
        lieu: String,
        faitOfficiel: String,
        faitVerifie: String,
        sources: [String],
        latitude: Double?,
        longitude: Double?,
        photoLatitude: Double? = nil,
        photoLongitude: Double? = nil,
        photoLocationConfidence: PhotoLocationConfidence? = nil,
        photoLocationAccuracyMeters: Double? = nil
    ) {
        self.lieu = lieu
        self.faitOfficiel = faitOfficiel
        self.faitVerifie = faitVerifie
        self.sources = sources
        self.latitude = latitude
        self.longitude = longitude
        self.photoLatitude = photoLatitude
        self.photoLongitude = photoLongitude
        self.photoLocationConfidence = photoLocationConfidence
        self.photoLocationAccuracyMeters = photoLocationAccuracyMeters
    }

    enum CodingKeys: String, CodingKey {
        case lieu
        case faitOfficiel = "fait_officiel"
        case faitVerifie = "fait_verifie"
        case sources
        case latitude, longitude
        case photoLatitude = "photo_latitude"
        case photoLongitude = "photo_longitude"
        case photoLocationConfidence = "photo_location_confidence"
        case photoLocationAccuracyMeters = "photo_location_accuracy_meters"
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

    var trustedPhotoCoordinate: CLLocationCoordinate2D? {
        photoLocationConfidence == .high ? photoCoordinate : nil
    }

    func acceptedPhotoCoordinate(allowingMedium: Bool) -> CLLocationCoordinate2D? {
        if photoLocationConfidence == .high {
            return photoCoordinate
        }
        return allowingMedium && photoLocationConfidence == .medium ? photoCoordinate : nil
    }

    var boundedPhotoLocationAccuracyMeters: Double? {
        guard let value = photoLocationAccuracyMeters, value.isFinite, value > 0 else {
            return nil
        }
        return min(max(value, 25), 100_000)
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

    var estimatedPhotoCoordinate: CLLocationCoordinate2D? {
        let components = modelIdentifier?
            .split(separator: ":", maxSplits: 1)
            .map(String.init) ?? []
        guard components.count == 2,
              let provider = LLMProvider(rawValue: components[0]) else {
            return fact.trustedPhotoCoordinate
        }
        let model = components[1].split(separator: "#", maxSplits: 1).first
            .map(String.init) ?? components[1]
        return fact.acceptedPhotoCoordinate(
            allowingMedium: provider.acceptsMediumPhotoConfidence(model: model)
        )
    }

    var estimatedPhotoAccuracyMeters: Double? {
        estimatedPhotoCoordinate == nil ? nil : fact.boundedPhotoLocationAccuracyMeters
    }

    var estimatedPhotoAccuracyLabel: String? {
        guard let meters = estimatedPhotoAccuracyMeters else { return nil }
        let distance = Measurement(value: meters, unit: UnitLength.meters).formatted(
            .measurement(width: .abbreviated, usage: .road)
        )
        return String(
            format: String(localized: "Rayon d’incertitude : environ %@"),
            locale: .current,
            distance
        )
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
