import CoreLocation

protocol ReverseGeocoding {
    func place(for coordinate: CLLocationCoordinate2D) async throws -> CapturedPlace
    func coordinate(for placeName: String) async throws -> CLLocationCoordinate2D
}

final class ReverseGeocodingService: ReverseGeocoding {
    private let geocoder = CLGeocoder()

    func place(for coordinate: CLLocationCoordinate2D) async throws -> CapturedPlace {
        let placemarks = try await geocoder.reverseGeocodeLocation(
            CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            preferredLocale: Locale(identifier: "fr_FR")
        )
        guard let placemark = placemarks.first else { throw AppError.geocodingFailed }
        return CapturedPlace(
            coordinate: coordinate,
            name: placemark.name ?? placemark.areasOfInterest?.first ?? placemark.locality ?? "Lieu inconnu",
            locality: placemark.locality,
            country: placemark.country
        )
    }

    func coordinate(for placeName: String) async throws -> CLLocationCoordinate2D {
        guard let location = try await geocoder.geocodeAddressString(placeName).first?.location else {
            throw AppError.geocodingFailed
        }
        return location.coordinate
    }
}
