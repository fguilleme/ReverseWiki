import CoreLocation
import Foundation

protocol LLMProviding {
    func fetchFact(imageData: Data, coordinate: CLLocationCoordinate2D?) async throws -> PlaceFact
}

enum LLMClientFactory {
    static func make(
        configuration: LLMConfiguration,
        session: URLSession = .shared
    ) -> LLMProviding {
        switch configuration.provider {
        case .anthropic:
            AnthropicClient(session: session, configuration: configuration)
        case .gemini:
            GeminiClient(session: session, configuration: configuration)
        case .openAI, .kimi, .openRouter, .custom:
            OpenAICompatibleClient(session: session, configuration: configuration)
        }
    }
}

enum FactPrompt {
    static let system = """
    Tu es un historien fact-checker prudent. Analyse d’abord la photo pour identifier ce qui est \
    réellement visible, sans aucun indice géographique externe. Produis ensuite un fait historique \
    peu connu ou corrige avec nuance un récit touristique répandu. N'invente jamais de source. \
    Cite uniquement des URL publiques et vérifiables. Si le lieu est ambigu, dis-le explicitement.
    Réponds exclusivement avec un objet JSON valide, sans Markdown ni texte avant/après, exactement \
    sous cette forme :
    {"lieu":"string","fait_officiel":"string","fait_verifie":"string","sources":["https://..."],\
    "latitude":number|null,"longitude":number|null}
    Les six champs sont obligatoires. Latitude et longitude doivent être les coordonnées décimales \
    du lieu identifié avec une précision raisonnable, ou null si le lieu n’est pas assez certain. \
    N’utilise jamais les coordonnées GPS facultatives fournies comme résultat sans avoir confirmé \
    qu’elles correspondent bien à l’image. Le champ "lieu" doit contenir uniquement le nom canonique \
    court du lieu et son pays, sans commentaire, comparaison, parenthèses ni explication. Écris en \
    français. Donne au moins deux sources distinctes lorsque cela est possible.
    """

    static func user(coordinate: CLLocationCoordinate2D?) -> String {
        guard let coordinate else {
            return "Identifie uniquement le sujet visible sur cette photo, puis réponds au format JSON demandé."
        }
        return """
        Identifie d’abord le sujet visible sur cette photo. Les coordonnées GPS facultatives \
        \(coordinate.latitude), \(coordinate.longitude) sont seulement un indice secondaire : \
        ignore-les si elles sont incompatibles avec l’image. Réponds ensuite au format JSON demandé.
        """
    }

    static func decode(_ text: String) throws -> PlaceFact {
        let candidate: Substring
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start <= end {
            candidate = text[start...end]
        } else {
            candidate = Substring(text)
        }
        guard let data = String(candidate).data(using: .utf8),
              let fact = try? JSONDecoder().decode(PlaceFact.self, from: data) else {
            throw AppError.invalidResponse
        }
        return fact
    }
}
