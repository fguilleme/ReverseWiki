import AppIntents

struct OpenCameraIntent: AppIntent {
    static let title: LocalizedStringResource = "Prendre une photo"
    static let description = IntentDescription(
        "Ouvre Reverse Wiki directement sur la caméra pour analyser un lieu."
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppIntentRouter.shared.requestCamera()
        return .result()
    }
}

struct ReverseWikiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenCameraIntent(),
            phrases: [
                "Prendre une photo avec \(.applicationName)",
                "Photographier un lieu avec \(.applicationName)",
                "Découvrir un lieu avec \(.applicationName)"
            ],
            shortTitle: "Prendre une photo",
            systemImageName: "camera.fill"
        )
    }
}
