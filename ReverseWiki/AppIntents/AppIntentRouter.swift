import Foundation
import Observation

@MainActor
@Observable
final class AppIntentRouter {
    struct CameraRequest: Identifiable, Equatable {
        let id = UUID()
    }

    static let shared = AppIntentRouter()
    var request: CameraRequest?

    private init() {}

    func requestCamera() {
        request = CameraRequest()
    }

    func consumeCameraRequest() -> Bool {
        guard request != nil else { return false }
        request = nil
        return true
    }
}
