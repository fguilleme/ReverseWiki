import CoreLocation
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct PhotoPickerView: UIViewControllerRepresentable {
    let onSelection: (UIImage, CLLocationCoordinate2D?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelection: onSelection) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onSelection: (UIImage, CLLocationCoordinate2D?) -> Void

        init(onSelection: @escaping (UIImage, CLLocationCoordinate2D?) -> Void) {
            self.onSelection = onSelection
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                picker.dismiss(animated: true)
                return
            }

            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) {
                [weak self] data, _ in
                guard let data, let image = UIImage(data: data) else { return }
                let coordinate = Self.gpsCoordinate(from: data)
                DispatchQueue.main.async {
                    self?.onSelection(image, coordinate)
                }
            }
        }

        private static func gpsCoordinate(from data: Data) -> CLLocationCoordinate2D? {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                    as? [CFString: Any],
                  let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
                  let latitude = gps[kCGImagePropertyGPSLatitude] as? NSNumber,
                  let longitude = gps[kCGImagePropertyGPSLongitude] as? NSNumber else {
                return nil
            }

            let latitudeReference = gps[kCGImagePropertyGPSLatitudeRef] as? String
            let longitudeReference = gps[kCGImagePropertyGPSLongitudeRef] as? String
            let signedLatitude = latitude.doubleValue * (latitudeReference == "S" ? -1 : 1)
            let signedLongitude = longitude.doubleValue * (longitudeReference == "W" ? -1 : 1)
            let coordinate = CLLocationCoordinate2D(
                latitude: signedLatitude,
                longitude: signedLongitude
            )
            return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
        }
    }
}
