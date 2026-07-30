import CoreLocation
import Foundation

protocol LLMProviding {
    func fetchFact(imageData: Data, coordinate: CLLocationCoordinate2D?) async throws -> PlaceFact
    func cacheIdentifier() async -> String
}

extension LLMProviding {
    func cacheIdentifier() async -> String {
        "legacy"
    }
}

final class ConfigurableLLMClient: LLMProviding {
    private let settings: LLMSettings
    private let session: URLSession

    init(settings: LLMSettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    func fetchFact(imageData: Data, coordinate: CLLocationCoordinate2D?) async throws -> PlaceFact {
        let configuration = await settings.configuration()
        let client = LLMClientFactory.make(configuration: configuration, session: session)
        return try await client.fetchFact(imageData: imageData, coordinate: coordinate)
    }

    func cacheIdentifier() async -> String {
        let configuration = await settings.configuration()
        return "\(configuration.provider.rawValue):\(configuration.model)#\(FactPrompt.cacheVersion)"
    }
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
    static let cacheVersion = "viewpoint-v2"

    static var system: String {
        let language = Locale.current.localizedString(
            forLanguageCode: Locale.current.language.languageCode?.identifier ?? "fr"
        ) ?? "français"
        return """
    Tu es un historien fact-checker prudent. Analyse d’abord la photo pour identifier ce qui est \
    réellement visible, sans aucun indice géographique externe. Produis ensuite un fait historique \
    peu connu ou corrige avec nuance un récit touristique répandu. N'invente jamais de source. \
    Cite uniquement des URL publiques et vérifiables. Si le lieu est ambigu, dis-le explicitement.
    Réponds exclusivement avec un objet JSON valide, sans Markdown ni texte avant/après, exactement \
    sous cette forme :
    {"lieu":"string","fait_officiel":"string","fait_verifie":"string","sources":["https://..."],\
    "latitude":number|null,"longitude":number|null,"photo_latitude":number|null,\
    "photo_longitude":number|null}
    Les huit champs sont obligatoires. Latitude et longitude sont les coordonnées décimales du lieu \
    identifié. Photo_latitude et photo_longitude sont celles du point où se trouvait probablement \
    le photographe. Déduis ce point de vue uniquement à partir d’indices visuels plausibles \
    (perspective, relief, rive, rue, façade ou panorama) et utilise null si la précision serait \
    trompeuse. \
    N’utilise jamais les coordonnées GPS facultatives fournies comme résultat sans avoir confirmé \
    qu’elles correspondent bien à l’image. Le champ "lieu" doit contenir uniquement le nom canonique \
    court du lieu et son pays, sans commentaire, comparaison, parenthèses ni explication. Écris en \
    \(language). Donne au moins deux sources distinctes lorsque cela est possible.
    """
    }

    static func user(coordinate: CLLocationCoordinate2D?) -> String {
        guard let coordinate else {
            return """
            Identifie uniquement le sujet visible sur cette photo. Aucune coordonnée GPS n’est \
            disponible : essaie aussi de déterminer d’où la photo a été prise et renseigne \
            photo_latitude et photo_longitude seulement si le point de vue peut être déduit avec \
            une précision raisonnable. Réponds au format JSON demandé.
            """
        }
        return """
        Identifie d’abord le sujet visible sur cette photo. Les coordonnées GPS facultatives \
        \(coordinate.latitude), \(coordinate.longitude) sont seulement un indice secondaire : \
        ignore-les si elles sont incompatibles avec l’image. Utilise-les pour photo_latitude et \
        photo_longitude uniquement si elles correspondent au point de vue visible. Réponds ensuite \
        au format JSON demandé.
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
