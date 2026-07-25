import Foundation

struct LLMModel: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}

protocol ModelCatalogProviding: Sendable {
    func models(for provider: LLMProvider, apiKey: String) async throws -> [LLMModel]
}

struct ModelCatalogService: ModelCatalogProviding {
    private struct OpenAIEnvelope: Decodable {
        struct Model: Decodable {
            let id: String
            let name: String?
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
            return try await openAIStyleModels(
                url: URL(string: "https://api.anthropic.com/v1/models"),
                headers: [
                    "x-api-key": apiKey,
                    "anthropic-version": "2023-06-01"
                ]
            )
        case .openAI:
            let models = try await openAIStyleModels(
                url: URL(string: "https://api.openai.com/v1/models"),
                headers: ["authorization": "Bearer \(apiKey)"]
            )
            return models.filter(Self.isOpenAIVisionCandidate)
        case .kimi:
            return try await openAIStyleModels(
                url: URL(string: "https://api.moonshot.ai/v1/models"),
                headers: ["authorization": "Bearer \(apiKey)"]
            )
        case .openRouter:
            return try await openAIStyleModels(
                url: URL(string: "https://openrouter.ai/api/v1/models?input_modalities=image&output_modalities=text"),
                headers: ["authorization": "Bearer \(apiKey)"]
            )
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
            .filter { $0.supportedGenerationMethods?.contains("generateContent") == true }
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
            .map { LLMModel(id: $0.id, name: $0.name ?? $0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func isOpenAIVisionCandidate(_ model: LLMModel) -> Bool {
        let id = model.id.lowercased()
        let excluded = ["audio", "realtime", "transcribe", "tts", "embedding", "image"]
        return (id.contains("gpt") || id.hasPrefix("o")) && !excluded.contains(where: id.contains)
    }
}
