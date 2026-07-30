import CoreLocation
import Foundation

final class AnthropicClient: LLMProviding {
    static let responseTokenBudget = 4_096

    private struct Request: Encodable {
        struct Message: Encodable {
            struct Content: Encodable {
                struct Source: Encodable {
                    let type: String
                    let mediaType: String
                    let data: String

                    enum CodingKeys: String, CodingKey {
                        case type, data
                        case mediaType = "media_type"
                    }
                }

                let type: String
                let text: String?
                let source: Source?

                static func jpeg(_ data: Data) -> Content {
                    Content(
                        type: "image",
                        text: nil,
                        source: Source(
                            type: "base64",
                            mediaType: "image/jpeg",
                            data: data.base64EncodedString()
                        )
                    )
                }

                static func text(_ value: String) -> Content {
                    Content(type: "text", text: value, source: nil)
                }
            }

            let role: String
            let content: [Content]
        }
        let model: String
        let maxTokens: Int
        let temperature: Double
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
        let stopReason: String?

        enum CodingKeys: String, CodingKey {
            case content
            case stopReason = "stop_reason"
        }
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
        let requestID = UUID()
        let startedAt = ContinuousClock.now
        let systemPrompt = FactPrompt.system
        let userPrompt = FactPrompt.user(coordinate: coordinate)
        LLMDiagnostics.logRequest(
            id: requestID,
            configuration: configuration,
            imageData: imageData,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.provider.analysisTimeout
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try requestBody(
            imageData: imageData,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )

        let data = try await HTTPValidator.data(for: request, session: session)
        let response = try JSONDecoder().decode(Response.self, from: data)
        let text = response.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()
        guard !text.isEmpty else {
            throw AppError.invalidResponse
        }
        LLMDiagnostics.logResponse(
            id: requestID,
            configuration: configuration,
            startedAt: startedAt,
            data: data,
            text: text,
            stopReason: response.stopReason
        )
        let fact: PlaceFact
        do {
            fact = try FactPrompt.decode(text)
        } catch {
            if response.stopReason == "max_tokens" {
                throw AppError.invalidResponseDetail(
                    String(localized: "La réponse a été tronquée par la limite de génération. Réessayez.")
                )
            }
            throw error
        }
        LLMDiagnostics.logDecoded(id: requestID, fact: fact)
        return fact
    }

    func requestBody(
        imageData: Data,
        systemPrompt: String,
        userPrompt: String
    ) throws -> Data {
        try JSONEncoder().encode(Request(
            model: configuration.model,
            maxTokens: Self.responseTokenBudget,
            temperature: configuration.temperature,
            system: systemPrompt,
            messages: [
                .init(
                    role: "user",
                    content: [
                        .jpeg(imageData),
                        .text(userPrompt)
                    ]
                )
            ]
        ))
    }
}
