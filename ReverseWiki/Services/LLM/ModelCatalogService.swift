import Foundation

struct LLMModel: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let inputModalities: Set<String>?

    init(id: String, name: String, inputModalities: Set<String>? = nil) {
        self.id = id
        self.name = name
        self.inputModalities = inputModalities
    }
}

protocol ModelCatalogProviding: Sendable {
    func models(for provider: LLMProvider, apiKey: String) async throws -> [LLMModel]
}

struct ModelCatalogService: ModelCatalogProviding {
    private struct OpenAIEnvelope: Decodable {
        struct Model: Decodable {
            struct Architecture: Decodable {
                let inputModalities: [String]?

                enum CodingKeys: String, CodingKey {
                    case inputModalities = "input_modalities"
                }
            }

            let id: String
            let name: String?
            let architecture: Architecture?
        }
        let data: [Model]
    }

    private struct GeminiEnvelope: Decodable {
        struct Model: Decodable {
            let name: String
            let displayName: String?
            let supportedGenerationMethods: [String]?
        }
        let models: [Model]
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func models(for provider: LLMProvider, apiKey: String) async throws -> [LLMModel] {
        guard !apiKey.isEmpty else {
            throw AppError.missingAPIKey(provider: provider.displayName)
        }

        switch provider {
        case .gemini:
            return try await geminiModels(apiKey: apiKey)
        case .anthropic:
            let models = try await openAIStyleModels(
                url: URL(string: "https://api.anthropic.com/v1/models"),
                headers: [
                    "x-api-key": apiKey,
                    "anthropic-version": "2023-06-01"
                ]
            )
            return models.filter { Self.supportsImageInput(modelID: $0.id, provider: .anthropic) }
        case .openAI:
            let models = try await openAIStyleModels(
                url: URL(string: "https://api.openai.com/v1/models"),
                headers: ["authorization": "Bearer \(apiKey)"]
            )
            return models.filter(Self.isOpenAIVisionCandidate)
        case .kimi:
            let models = try await openAIStyleModels(
                url: URL(string: "https://api.moonshot.ai/v1/models"),
                headers: ["authorization": "Bearer \(apiKey)"]
            )
            return models.filter { Self.supportsImageInput(modelID: $0.id, provider: .kimi) }
        case .openRouter:
            let models = try await openAIStyleModels(
                url: URL(string: "https://openrouter.ai/api/v1/models?input_modalities=image&output_modalities=text"),
                headers: ["authorization": "Bearer \(apiKey)"]
            )
            return models.filter { $0.inputModalities?.contains("image") == true }
        case .custom:
            return []
        }
    }

    private func geminiModels(apiKey: String) async throws -> [LLMModel] {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models") else {
            throw AppError.invalidConfiguration
        }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        let data = try await HTTPValidator.data(for: request, session: session)
        let response = try JSONDecoder().decode(GeminiEnvelope.self, from: data)
        return response.models
            .filter {
                $0.supportedGenerationMethods?.contains("generateContent") == true
                    && Self.supportsImageInput(
                        modelID: $0.name.replacingOccurrences(of: "models/", with: ""),
                        provider: .gemini
                    )
            }
            .map {
                let identifier = $0.name.replacingOccurrences(of: "models/", with: "")
                return LLMModel(id: identifier, name: $0.displayName ?? identifier)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func openAIStyleModels(
        url: URL?,
        headers: [String: String]
    ) async throws -> [LLMModel] {
        guard let url else { throw AppError.invalidConfiguration }
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let data = try await HTTPValidator.data(for: request, session: session)
        let response = try JSONDecoder().decode(OpenAIEnvelope.self, from: data)
        return response.data
            .map {
                LLMModel(
                    id: $0.id,
                    name: $0.name ?? $0.id,
                    inputModalities: $0.architecture?.inputModalities.map(Set.init)
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func isOpenAIVisionCandidate(_ model: LLMModel) -> Bool {
        supportsImageInput(modelID: model.id, provider: .openAI)
    }

    static func supportsImageInput(modelID: String, provider: LLMProvider) -> Bool {
        let id = modelID.lowercased()
        let excluded = [
            "audio", "realtime", "transcribe", "tts", "embedding",
            "image-generation", "native-audio", "live", "veo", "imagen"
        ]
        guard !excluded.contains(where: id.contains) else { return false }

        switch provider {
        case .gemini:
            return id.hasPrefix("gemini-")
                && !id.contains("-image")
                && !id.contains("banana")
                && !id.contains("computer-use")
                && !id.contains("deep-research")
                && !id.contains("robotics")
        case .anthropic:
            return id.hasPrefix("claude-")
                && !id.hasPrefix("claude-2")
                && !id.contains("instant")
        case .openAI:
            let visionFamilies = [
                "gpt-4o", "gpt-4.1", "gpt-4.5", "gpt-4-turbo", "gpt-5"
            ]
            if visionFamilies.contains(where: id.hasPrefix) {
                return true
            }
            if id == "o1" || id.hasPrefix("o1-20") || id.hasPrefix("o1-pro") {
                return true
            }
            if id == "o3" || id.hasPrefix("o3-20") || id.hasPrefix("o3-pro") {
                return true
            }
            return id.hasPrefix("o4-mini")
        case .kimi:
            return id.contains("vision") || id.contains("k2.5")
        case .openRouter:
            return false
        case .custom:
            return false
        }
    }
}
