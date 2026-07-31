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
    @ObservationIgnored private var analysisTask: Task<Void, Never>?
    @ObservationIgnored private var analysisID: UUID?

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
        startAnalysis(imageData: data) { [locationService] in
            do {
                return try await locationService.currentLocation().coordinate
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                return nil
            }
        }
    }

    func processImportedImage(_ image: UIImage, coordinate: CLLocationCoordinate2D?) {
        guard let data = image.normalizedJPEGData() else {
            state = .failed(AppError.invalidImage.localizedDescription)
            return
        }
        state = .processing
        startAnalysis(coordinate: coordinate, imageData: data)
    }

    func reset() {
        cancelAnalysis()
    }

    func cancelAnalysis() {
        analysisID = nil
        analysisTask?.cancel()
        analysisTask = nil
        state = .ready
    }

    private func startAnalysis(
        coordinate: CLLocationCoordinate2D?,
        imageData: Data
    ) {
        startAnalysis(imageData: imageData) { coordinate }
    }

    private func startAnalysis(
        imageData: Data,
        coordinate: @escaping @MainActor () async throws -> CLLocationCoordinate2D?
    ) {
        analysisTask?.cancel()
        let id = UUID()
        analysisID = id
        analysisTask = Task { [weak self] in
            guard let self else { return }
            do {
                let resolvedCoordinate = try await coordinate()
                try Task.checkCancellation()
                await analyze(
                    id: id,
                    imageData: imageData,
                    coordinate: resolvedCoordinate
                )
            } catch is CancellationError {
                finishCancelledAnalysis(id: id)
            } catch {
                finishFailedAnalysis(id: id, error: error)
            }
        }
    }

    private func analyze(
        id: UUID,
        imageData: Data,
        coordinate: CLLocationCoordinate2D?
    ) async {
        do {
            let analysis = try await placeFactService.analyze(
                for: coordinate,
                imageData: imageData
            )
            try Task.checkCancellation()
            guard analysisID == id else { return }
            state = .result(CaptureResult(
                imageData: imageData,
                coordinate: analysis.coordinate,
                fact: analysis.fact,
                modelIdentifier: analysis.modelIdentifier
            ))
            analysisID = nil
            analysisTask = nil
        } catch is CancellationError {
            finishCancelledAnalysis(id: id)
        } catch {
            finishFailedAnalysis(id: id, error: error)
        }
    }

    private func finishCancelledAnalysis(id: UUID) {
        guard analysisID == id else { return }
        analysisID = nil
        analysisTask = nil
        state = .ready
    }

    private func finishFailedAnalysis(id: UUID, error: Error) {
        guard analysisID == id else { return }
        analysisID = nil
        analysisTask = nil
        state = .failed(error.localizedDescription)
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
