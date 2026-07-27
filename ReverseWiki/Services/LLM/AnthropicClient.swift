import CoreLocation
import Foundation

final class AnthropicClient: LLMProviding {
    private struct Request: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        let model: String
        let maxTokens: Int
        let system: String
        let messages: [Message]

        enum CodingKeys: String, CodingKey {
            case model, system, messages
            case maxTokens = "max_tokens"
        }
    }

    private struct Response: Decodable {
        struct Content: Decodable { let type: String; let text: String? }
        let content: [Content]
    }

    private let session: URLSession
    private let configuration: LLMConfiguration

    init(session: URLSession, configuration: LLMConfiguration) {
        self.session = session
        self.configuration = configuration
    }

    func fetchFact(imageData: Data, coordinate: CLLocationCoordinate2D?) async throws -> PlaceFact {
        guard let key = configuration.apiKey, !key.isEmpty else {
            throw AppError.missingAPIKey(provider: "Anthropic")
        }
        guard let endpoint = configuration.endpoint else { throw AppError.invalidConfiguration }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.provider.analysisTimeout
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(Request(
            model: configuration.model,
            maxTokens: 900,
            system: FactPrompt.system,
            messages: [.init(role: "user", content: FactPrompt.user(coordinate: coordinate))]
        ))

        let data = try await HTTPValidator.data(for: request, session: session)
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let text = response.content.first(where: { $0.type == "text" })?.text else {
            throw AppError.invalidResponse
        }
        return try FactPrompt.decode(text)
    }
}
