import Foundation

enum AppError: LocalizedError {
    case invalidImage
    case locationPermissionDenied
    case locationUnavailable
    case geocodingFailed
    case missingAPIKey(provider: String)
    case invalidConfiguration
    case invalidResponse
    case server(statusCode: Int, message: String)
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: "L’image sélectionnée est illisible."
        case .locationPermissionDenied:
            "L’accès à la localisation est désactivé. Autorisez-le dans Réglages pour identifier ce lieu."
        case .locationUnavailable:
            "Position introuvable. Sur le simulateur, choisissez une position dans Features > Location."
        case .geocodingFailed: "Impossible d’identifier le lieu à partir des coordonnées."
        case let .missingAPIKey(provider): "La clé API \(provider) n’est pas configurée."
        case .invalidConfiguration: "La configuration du fournisseur IA est invalide."
        case .invalidResponse: "Le fournisseur IA a renvoyé une réponse inattendue."
        case let .server(statusCode, message): "Erreur API \(statusCode) : \(message)"
        case .exportFailed: "Impossible de générer l’image à partager."
        }
    }
}
