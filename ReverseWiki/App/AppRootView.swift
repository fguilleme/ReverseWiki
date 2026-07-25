import SwiftUI

enum AppTab: Hashable {
    case capture
    case history
}

struct AppRootView: View {
    @State private var selectedTab: AppTab = .capture
    @State private var captureViewModel: CaptureViewModel
    @State private var historyViewModel: HistoryViewModel
    @State private var intentRouter = AppIntentRouter.shared

    init(dependencies: AppDependencies) {
        _captureViewModel = State(initialValue: CaptureViewModel(
            locationService: dependencies.locationService,
            placeFactService: dependencies.placeFactService
        ))
        _historyViewModel = State(initialValue: HistoryViewModel(cache: dependencies.cache))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CaptureView(viewModel: captureViewModel)
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
            handlePendingIntent()
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
    }

    private func handlePendingIntent() {
        guard intentRouter.consumeCameraRequest() else { return }
        selectedTab = .capture
        captureViewModel.reset()
        captureViewModel.isCameraPresented = true
    }
}
