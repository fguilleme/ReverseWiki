import SwiftUI

enum AppTab: Hashable {
    case capture
    case history
}

struct AppRootView: View {
    private enum HelpPresentation: String, Identifiable {
        case firstLaunch
        case manual

        var id: String { rawValue }
    }

    @AppStorage("hasCompletedInitialHelp") private var hasCompletedInitialHelp = false
    @State private var selectedTab: AppTab = .capture
    @State private var captureViewModel: CaptureViewModel
    @State private var historyViewModel: HistoryViewModel
    @State private var intentRouter = AppIntentRouter.shared
    @State private var helpPresentation: HelpPresentation?
    private let llmSettings: LLMSettings
    private let modelCatalog: ModelCatalogProviding

    init(dependencies: AppDependencies) {
        llmSettings = dependencies.llmSettings
        modelCatalog = dependencies.modelCatalog
        _captureViewModel = State(initialValue: CaptureViewModel(
            locationService: dependencies.locationService,
            placeFactService: dependencies.placeFactService
        ))
        _historyViewModel = State(initialValue: HistoryViewModel(cache: dependencies.cache))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CaptureView(
                viewModel: captureViewModel,
                llmSettings: llmSettings,
                modelCatalog: modelCatalog,
                onShowHelp: {
                    helpPresentation = .manual
                }
            )
                .tabItem {
                    Label("Découvrir", systemImage: "camera")
                }
                .tag(AppTab.capture)

            HistoryView(viewModel: historyViewModel)
                .tabItem {
                    Label("Historique", systemImage: "clock.arrow.circlepath")
                }
                .tag(AppTab.history)
        }
        .task {
            if hasCompletedInitialHelp {
                handlePendingIntent()
            } else {
                helpPresentation = .firstLaunch
            }
        }
        .onChange(of: intentRouter.request?.id) {
            handlePendingIntent()
        }
        .onChange(of: selectedTab) {
            guard selectedTab == .history else { return }
            Task {
                await historyViewModel.load()
            }
        }
        .fullScreenCover(item: $helpPresentation) { presentation in
            HelpView(isFirstLaunch: presentation == .firstLaunch) {
                if presentation == .firstLaunch {
                    hasCompletedInitialHelp = true
                }
                helpPresentation = nil
                handlePendingIntent()
            }
        }
    }

    private func handlePendingIntent() {
        guard intentRouter.consumeCameraRequest() else { return }
        selectedTab = .capture
        captureViewModel.reset()
        captureViewModel.isCameraPresented = true
    }
}
