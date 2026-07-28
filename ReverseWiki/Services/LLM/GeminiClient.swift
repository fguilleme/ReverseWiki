import CoreLocation
import Foundation

final class GeminiClient: LLMProviding {
    private struct Request: Encodable {
        struct Content: Encodable {
            struct Part: Encodable {
                struct InlineData: Encodable {
                    let mimeType: String
                    let data: String
                }

                let text: String?
                let inlineData: InlineData?

                static func text(_ text: String) -> Part {
                    Part(text: text, inlineData: nil)
                }

                static func jpeg(_ data: Data) -> Part {
                    Part(
                        text: nil,
                        inlineData: InlineData(
                            mimeType: "image/jpeg",
                            data: data.base64EncodedString()
                        )
                    )
                }
            }
            let parts: [Part]
        }
        struct GenerationConfig: Encodable {
            let temperature: Double
            let responseMimeType: String
        }

        let systemInstruction: Content
        let contents: [Content]
        let generationConfig: GenerationConfig
    }

    private struct Response: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable { let text: String? }
                let parts: [Part]
            }
            let content: Content
        }
        let candidates: [Candidate]
    }

    private let session: URLSession
    private let configuration: LLMConfiguration

    init(session: URLSession, configuration: LLMConfiguration) {
        self.session = session
        self.configuration = configuration
    }

    func fetchFact(imageData: Data, coordinate: CLLocationCoordinate2D?) async throws -> PlaceFact {
        guard let key = configuration.apiKey, !key.isEmpty else {
            throw AppError.missingAPIKey(provider: "Gemini")
        }
        let endpoint = configuration.endpoint ?? URL(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(configuration.model):generateContent"
        )
        guard let endpoint, !configuration.model.isEmpty else {
            throw AppError.invalidConfiguration
        }
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
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        let parts: [Request.Content.Part] = [
            .text(userPrompt),
            .jpeg(imageData)
        ]
        request.httpBody = try JSONEncoder().encode(Request(
            systemInstruction: .init(parts: [.text(systemPrompt)]),
            contents: [.init(parts: parts)],
            generationConfig: .init(
                temperature: configuration.temperature,
                responseMimeType: "application/json"
            )
        ))

        let data = try await HTTPValidator.data(for: request, session: session)
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let text = response.candidates.first?.content.parts.first?.text else {
            throw AppError.invalidResponse
        }
        LLMDiagnostics.logResponse(
            id: requestID,
            configuration: configuration,
            startedAt: startedAt,
            data: data,
            text: text
        )
        let fact = try FactPrompt.decode(text)
        LLMDiagnostics.logDecoded(id: requestID, fact: fact)
        return fact
    }
}
