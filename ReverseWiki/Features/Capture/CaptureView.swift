import SwiftUI

struct CaptureView: View {
    @State var viewModel: CaptureViewModel
    let llmSettings: LLMSettings
    let modelCatalog: ModelCatalogProviding
    let onShowHelp: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .ready:
                    options
                case .processing:
                    VStack(spacing: 16) {
                        ProgressView().controlSize(.large)
                        Text("Identification et vérification…").font(.headline)
                        Text("Localisation du lieu, recherche du contexte et vérification des sources.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(32)
                case let .result(result):
                    ResultView(result: result, onRestart: viewModel.reset)
                case let .failed(message):
                    ContentUnavailableView {
                        Label("Échec de l’analyse", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Réessayer", action: viewModel.reset).buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Reverse Wiki")
            .toolbar {
                if viewModel.canReturnHome {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: viewModel.reset) {
                            Label("Accueil", systemImage: "chevron.left")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onShowHelp) {
                        Label("Aide", systemImage: "questionmark.circle")
                    }
                }
            }
            .fullScreenCover(isPresented: $viewModel.isCameraPresented) {
                CameraView { image in
                    viewModel.isCameraPresented = false
                    viewModel.processCapturedImage(image)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $viewModel.isPhotoPickerPresented) {
                PhotoPickerView { image, coordinate in
                    viewModel.isPhotoPickerPresented = false
                    viewModel.processImportedImage(image, coordinate: coordinate)
                }
            }
        }
    }

    private var options: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.indigo)
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text("Regardez derrière le récit").font(.title2.bold())
                    Text("Photographiez un lieu pour découvrir une histoire vérifiée et sourcée.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                LLMSelectionView(settings: llmSettings, modelCatalog: modelCatalog)

                VStack(spacing: 12) {
                    Button {
                        viewModel.isCameraPresented = true
                    } label: {
                        Label("Prendre une photo", systemImage: "camera.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        viewModel.isPhotoPickerPresented = true
                    } label: {
                        Label("Importer une photo", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(24)
        }
    }
}
