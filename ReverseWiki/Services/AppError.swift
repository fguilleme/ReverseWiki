import Foundation

enum AppError: LocalizedError {
    case invalidImage
    case locationPermissionDenied
    case locationUnavailable
    case geocodingFailed
    case missingAPIKey(provider: String)
    case invalidConfiguration
    case invalidResponse
    case invalidResponseDetail(String)
    case noCompatibleModels(provider: String, received: Int, sample: [String])
    case server(statusCode: Int, message: String)
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            String(localized: "L’image sélectionnée est illisible.")
        case .locationPermissionDenied:
            String(localized: "L’accès à la localisation est désactivé. Autorisez-le dans Réglages pour identifier ce lieu.")
        case .locationUnavailable:
            String(localized: "Position introuvable. Sur le simulateur, choisissez une position dans Features > Location.")
        case .geocodingFailed:
            String(localized: "Impossible d’identifier le lieu à partir des coordonnées.")
        case let .missingAPIKey(provider):
            String(
                format: String(localized: "La clé API %@ n’est pas configurée."),
                locale: .current,
                provider
            )
        case .invalidConfiguration:
            String(localized: "La configuration du fournisseur IA est invalide.")
        case .invalidResponse:
            String(localized: "Le fournisseur IA a renvoyé une réponse inattendue.")
        case let .invalidResponseDetail(detail):
            String(
                format: String(localized: "Le fournisseur IA a renvoyé une réponse inattendue : %@"),
                locale: .current,
                detail
            )
        case let .noCompatibleModels(provider, received, sample):
            String(
                format: String(localized: "%@ a renvoyé %lld modèle(s), mais aucun n’a été reconnu comme compatible texte + image. Modèles reçus : %@"),
                locale: .current,
                provider,
                Int64(received),
                sample.isEmpty ? "—" : sample.joined(separator: ", ")
            )
        case let .server(statusCode, message):
            String(
                format: String(localized: "Erreur API %lld : %@"),
                locale: .current,
                Int64(statusCode),
                message
            )
        case .exportFailed:
            String(localized: "Impossible de générer l’image à partager.")
        }
    }
}
