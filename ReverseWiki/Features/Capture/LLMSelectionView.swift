import SwiftUI

struct LLMSelectionView: View {
    let settings: LLMSettings
    let modelCatalog: ModelCatalogProviding

    @State private var editedProvider: LLMProvider?
    @State private var isExpanded = AppStoreScreenshotMode.current == .settings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isExpanded {
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
                    Button {
                        withAnimation(.snappy) {
                            isExpanded = false
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .accessibilityLabel("Replier les réglages")
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
                            Text(settings.isLoadingModels
                                 ? String(localized: "Chargement…")
                                 : String(localized: "Aucun modèle chargé"))
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
                        selectionRow(title: "Modèle", value: selectedModelName)
                    }
                    .disabled(settings.isLoadingModels || settings.availableModels.isEmpty)
                }

                status
            } else {
                Button {
                    withAnimation(.snappy) {
                        isExpanded = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                        Text(selectedModelName)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(expandAccessibilityLabel))
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .task(id: settings.provider) {
            guard AppStoreScreenshotMode.current == nil else { return }
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

    private func selectionRow(title: LocalizedStringKey, value: String) -> some View {
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

    private var selectedModelName: String {
        guard !settings.selectedModel.isEmpty else {
            return String(localized: "Choisir un modèle")
        }
        return settings.availableModels.first(where: { $0.id == settings.selectedModel })?.name
            ?? settings.selectedModel
    }

    private var expandAccessibilityLabel: String {
        String(
            format: String(localized: "Modèle %@. Déplier les réglages"),
            locale: .current,
            selectedModelName
        )
    }
}

private struct LLMCredentialsView: View {
    let provider: LLMProvider
    let settings: LLMSettings
    let modelCatalog: ModelCatalogProviding

    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String
    @State private var temperature: Double
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
        _temperature = State(initialValue: settings.temperature(
            for: provider,
            model: settings.selectedModel
        ))
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

                Section {
                    Stepper(value: $temperature, in: 0...2, step: 0.1) {
                        LabeledContent(
                            "Température",
                            value: temperature.formatted(
                                .number.precision(.fractionLength(1))
                            )
                        )
                    }
                } header: {
                    Text("Paramètres du modèle")
                } footer: {
                    Text("Certains modèles imposent une valeur précise, par exemple 1,0.")
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
            settings.saveTemperature(
                temperature,
                for: provider,
                model: settings.selectedModel
            )
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
