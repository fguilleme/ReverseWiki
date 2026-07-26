import Foundation
import Observation

@MainActor
@Observable
final class LLMSettings {
    private enum PreferenceKey {
        static let provider = "llm.selected-provider"
        static func model(_ provider: LLMProvider) -> String {
            "llm.selected-model.\(provider.rawValue)"
        }
    }

    var provider: LLMProvider {
        didSet {
            defaults.set(provider.rawValue, forKey: PreferenceKey.provider)
            selectedModel = savedModel(for: provider)
            availableModels = []
            modelLoadingError = nil
        }
    }
    var selectedModel: String {
        didSet {
            guard !selectedModel.isEmpty else { return }
            defaults.set(selectedModel, forKey: PreferenceKey.model(provider))
        }
    }
    private(set) var availableModels: [LLMModel] = []
    private(set) var isLoadingModels = false
    private(set) var modelLoadingError: String?

    private let defaults: UserDefaults
    private let keychain: KeychainStore
    private let bundleConfiguration: LLMConfiguration

    init(
        defaults: UserDefaults = .standard,
        keychain: KeychainStore = KeychainStore(),
        bundleConfiguration: LLMConfiguration = .fromBundle()
    ) {
        self.defaults = defaults
        self.keychain = keychain
        self.bundleConfiguration = bundleConfiguration
        let savedProvider = defaults.string(forKey: PreferenceKey.provider)
            .flatMap(LLMProvider.init(rawValue:))
        provider = savedProvider ?? bundleConfiguration.provider
        selectedModel = ""
        selectedModel = savedModel(for: provider)

        if keychain.value(for: bundleConfiguration.provider) == nil,
           let bundledKey = bundleConfiguration.apiKey,
           !bundledKey.isEmpty,
           bundledKey != "replace-me" {
            try? keychain.set(bundledKey, for: bundleConfiguration.provider)
        }
    }

    func apiKey(for provider: LLMProvider? = nil) -> String {
        keychain.value(for: provider ?? self.provider) ?? ""
    }

    func saveAPIKey(_ value: String, for provider: LLMProvider? = nil) throws {
        try keychain.set(value, for: provider ?? self.provider)
    }

    func configuration() -> LLMConfiguration {
        LLMConfiguration(
            provider: provider,
            apiKey: apiKey(),
            model: selectedModel,
            endpoint: provider.defaultEndpoint
        )
    }

    func refreshModels(using catalog: ModelCatalogProviding) async {
        let requestedProvider = provider
        let key = apiKey(for: requestedProvider)
        guard !key.isEmpty else {
            availableModels = []
            modelLoadingError = "Ajoutez une clé API pour charger les modèles."
            return
        }

        isLoadingModels = true
        modelLoadingError = nil
        defer { isLoadingModels = false }

        do {
            let models = try await catalog.models(for: requestedProvider, apiKey: key)
            guard provider == requestedProvider else { return }
            availableModels = models
            if models.isEmpty {
                selectedModel = ""
                defaults.removeObject(forKey: PreferenceKey.model(requestedProvider))
                modelLoadingError = "Aucun modèle compatible texte + image n’est disponible."
            } else if !models.contains(where: { $0.id == selectedModel }), let first = models.first {
                selectedModel = first.id
            }
        } catch {
            guard provider == requestedProvider else { return }
            availableModels = []
            modelLoadingError = error.localizedDescription
        }
    }

    private func savedModel(for provider: LLMProvider) -> String {
        if let saved = defaults.string(forKey: PreferenceKey.model(provider)), !saved.isEmpty {
            return saved
        }
        if provider == bundleConfiguration.provider, !bundleConfiguration.model.isEmpty {
            return bundleConfiguration.model
        }
        return provider.defaultModel
    }
}
