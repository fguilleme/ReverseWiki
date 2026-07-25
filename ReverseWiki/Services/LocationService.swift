import CoreLocation

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func currentLocation() async throws -> CLLocation {
        guard continuation == nil else { throw AppError.locationUnavailable }

        return try await withCheckedThrowingContinuation {
            continuation = $0

            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                resume(.failure(AppError.locationPermissionDenied))
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            @unknown default:
                resume(.failure(AppError.locationUnavailable))
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: resume(.failure(AppError.locationPermissionDenied))
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            resume(.failure(AppError.locationUnavailable))
            return
        }
        resume(.success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let coreLocationError = error as? CLError else {
            resume(.failure(error))
            return
        }

        switch coreLocationError.code {
        case .denied:
            resume(.failure(AppError.locationPermissionDenied))
        case .locationUnknown:
            resume(.failure(AppError.locationUnavailable))
        default:
            resume(.failure(error))
        }
    }

    private func resume(_ result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
