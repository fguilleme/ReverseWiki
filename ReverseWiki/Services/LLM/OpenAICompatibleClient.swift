import CoreLocation
import Foundation

final class OpenAICompatibleClient: LLMProviding {
    private struct Request: Encodable {
        struct Message: Encodable {
            enum Content: Encodable {
                case text(String)
                case parts([Part])

                func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    switch self {
                    case let .text(text):
                        try container.encode(text)
                    case let .parts(parts):
                        try container.encode(parts)
                    }
                }
            }

            struct Part: Encodable {
                struct ImageURL: Encodable {
                    let url: String
                }

                let type: String
                let text: String?
                let imageURL: ImageURL?

                enum CodingKeys: String, CodingKey {
                    case type
                    case text
                    case imageURL = "image_url"
                }

                static func text(_ value: String) -> Part {
                    Part(type: "text", text: value, imageURL: nil)
                }

                static func image(_ dataURL: String) -> Part {
                    Part(type: "image_url", text: nil, imageURL: ImageURL(url: dataURL))
                }
            }

            let role: String
            let content: Content
        }
        let model: String
        let messages: [Message]
        let temperature: Double
    }

    private struct Response: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    private let session: URLSession
    private let configuration: LLMConfiguration

    init(session: URLSession, configuration: LLMConfiguration) {
        self.session = session
        self.configuration = configuration
    }

    func fetchFact(imageData: Data, coordinate: CLLocationCoordinate2D?) async throws -> PlaceFact {
        guard let key = configuration.apiKey, !key.isEmpty else {
            throw AppError.missingAPIKey(provider: configuration.provider.rawValue)
        }
        guard let endpoint = configuration.endpoint,
              !configuration.model.isEmpty else {
            throw AppError.invalidConfiguration
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "authorization")
        let imageURL = "data:image/jpeg;base64,\(imageData.base64EncodedString())"
        request.httpBody = try JSONEncoder().encode(Request(
            model: configuration.model,
            messages: [
                .init(role: "system", content: .text(FactPrompt.system)),
                .init(
                    role: "user",
                    content: .parts([
                        .text(FactPrompt.user(coordinate: coordinate)),
                        .image(imageURL)
                    ])
                )
            ],
            temperature: 0.2
        ))

        let data = try await HTTPValidator.data(for: request, session: session)
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let text = response.choices.first?.message.content else {
            throw AppError.invalidResponse
        }
        return try FactPrompt.decode(text)
    }
}

enum HTTPValidator {
    private struct ErrorEnvelope: Decodable {
        struct Detail: Decodable { let message: String? }
        let error: Detail?
    }

    static func data(for request: URLRequest, session: URLSession) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AppError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            throw AppError.server(
                statusCode: http.statusCode,
                message: envelope?.error?.message ?? String(localized: "Réponse inconnue")
            )
        }
        return data
    }
}
