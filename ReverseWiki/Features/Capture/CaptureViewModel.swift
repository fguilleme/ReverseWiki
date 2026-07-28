import CoreLocation
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class CaptureViewModel {
    enum State {
        case ready
        case processing
        case result(CaptureResult)
        case failed(String)
    }

    var state: State = .ready
    var isCameraPresented = false
    var isPhotoPickerPresented = false

    var canReturnHome: Bool {
        if case .ready = state {
            return false
        }
        return true
    }

    private let locationService: LocationService
    private let placeFactService: PlaceFactProviding

    init(locationService: LocationService, placeFactService: PlaceFactProviding) {
        self.locationService = locationService
        self.placeFactService = placeFactService
    }

    func processCapturedImage(_ image: UIImage) {
        guard let data = image.normalizedJPEGData() else {
            state = .failed(AppError.invalidImage.localizedDescription)
            return
        }
        state = .processing
        Task {
            let coordinate = (try? await locationService.currentLocation())?.coordinate
            await analyze(imageData: data, coordinate: coordinate)
        }
    }

    func processImportedImage(_ image: UIImage, coordinate: CLLocationCoordinate2D?) {
        guard let data = image.normalizedJPEGData() else {
            state = .failed(AppError.invalidImage.localizedDescription)
            return
        }
        state = .processing
        Task {
            await analyze(imageData: data, coordinate: coordinate)
        }
    }

    func reset() {
        state = .ready
    }

    private func analyze(imageData: Data, coordinate: CLLocationCoordinate2D?) async {
        do {
            let analysis = try await placeFactService.analyze(
                for: coordinate,
                imageData: imageData
            )
            state = .result(CaptureResult(
                imageData: imageData,
                coordinate: analysis.coordinate,
                fact: analysis.fact,
                modelIdentifier: analysis.modelIdentifier
            ))
        } catch is CancellationError {
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

extension UIImage {
    func normalizedJPEGData() -> Data? {
        let maximumDimension: CGFloat = 1_600
        let scale = min(1, maximumDimension / max(size.width, size.height))
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: targetSize)) }
            .jpegData(compressionQuality: 0.85)
    }
}
