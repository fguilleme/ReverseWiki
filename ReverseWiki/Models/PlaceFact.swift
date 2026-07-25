import CoreLocation
import Foundation

struct PlaceFact: Codable, Equatable, Sendable {
    let lieu: String
    let faitOfficiel: String
    let faitVerifie: String
    let sources: [String]
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case lieu
        case faitOfficiel = "fait_officiel"
        case faitVerifie = "fait_verifie"
        case sources
        case latitude, longitude
    }

    var identifiedCoordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
}

struct PlaceAnalysis: Sendable {
    let fact: PlaceFact
    let coordinate: CLLocationCoordinate2D?
}

struct HistoryEntry: Identifiable, Sendable {
    let id: String
    let imageData: Data
    let date: Date
    let fact: PlaceFact
    let coordinate: CLLocationCoordinate2D?

    var captureResult: CaptureResult {
        CaptureResult(imageData: imageData, coordinate: coordinate, fact: fact)
    }
}
