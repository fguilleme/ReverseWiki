import SwiftUI

struct LLMSelectionView: View {
    let settings: LLMSettings
    let modelCatalog: ModelCatalogProviding

    @State private var editedProvider: LLMProvider?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Intelligence artificielle", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Button {
                    editedProvider = settings.provider
                } label: {
                    Image(systemName: "key")
                }
                .accessibilityLabel("Configurer la clé API")
            }

            Menu {
                ForEach(LLMProvider.allCases.filter { $0 != .custom }) { provider in
                    Button {
                        settings.provider = provider
                    } label: {
                        if provider == settings.provider {
                            Label(provider.displayName, systemImage: "checkmark")
                        } else {
                            Text(provider.displayName)
                        }
                    }
                }
            } label: {
                selectionRow(title: "Fournisseur", value: settings.provider.displayName)
            }

            if settings.provider == .custom {
                TextField("Identifiant du modèle", text: customModelBinding)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                Menu {
                    if settings.availableModels.isEmpty {
                        Text(settings.isLoadingModels ? "Chargement…" : "Aucun modèle chargé")
                    } else {
                        ForEach(settings.availableModels) { model in
                            Button {
                                settings.selectedModel = model.id
                            } label: {
                                if model.id == settings.selectedModel {
                                    Label(model.name, systemImage: "checkmark")
                                } else {
                                    Text(model.name)
                                }
                            }
                        }
                    }
                } label: {
                    selectionRow(
                        title: "Modèle",
                        value: settings.selectedModel.isEmpty ? "Choisir" : settings.selectedModel
                    )
                }
                .disabled(settings.isLoadingModels || settings.availableModels.isEmpty)
            }

            status
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .task(id: settings.provider) {
            await settings.refreshModels(using: modelCatalog)
        }
        .sheet(item: $editedProvider) { provider in
            LLMCredentialsView(
                provider: provider,
                settings: settings,
                modelCatalog: modelCatalog
            )
        }
    }

    @ViewBuilder
    private var status: some View {
        if settings.isLoadingModels {
            HStack(spacing: 8) {
                ProgressView()
                Text("Chargement des modèles…")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if let error = settings.modelLoadingError {
            HStack(alignment: .firstTextBaseline) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Configurer") {
                    editedProvider = settings.provider
                }
                .font(.caption.bold())
            }
        } else {
            Button {
                Task {
                    await settings.refreshModels(using: modelCatalog)
                }
            } label: {
                Label("Actualiser les modèles", systemImage: "arrow.clockwise")
            }
            .font(.caption)
        }
    }

    private func selectionRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private var customModelBinding: Binding<String> {
        Binding(
            get: { settings.selectedModel },
            set: { settings.selectedModel = $0 }
        )
    }
}

private struct LLMCredentialsView: View {
    let provider: LLMProvider
    let settings: LLMSettings
    let modelCatalog: ModelCatalogProviding

    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(
        provider: LLMProvider,
        settings: LLMSettings,
        modelCatalog: ModelCatalogProviding
    ) {
        self.provider = provider
        self.settings = settings
        self.modelCatalog = modelCatalog
        _apiKey = State(initialValue: settings.apiKey(for: provider))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Coller la clé API", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if let url = provider.keyCreationURL {
                        Link(destination: url) {
                            Label("Créer une clé chez \(provider.displayName)", systemImage: "arrow.up.right.square")
                        }
                    } else {
                        Text("Ce fournisseur personnalisé ne possède pas de page de clés connue.")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Clé API \(provider.displayName)")
                } footer: {
                    Text("La clé est conservée dans le Trousseau de cet appareil.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(provider.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        save()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        do {
            try settings.saveAPIKey(apiKey, for: provider)
            Task {
                if settings.provider == provider {
                    await settings.refreshModels(using: modelCatalog)
                }
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
