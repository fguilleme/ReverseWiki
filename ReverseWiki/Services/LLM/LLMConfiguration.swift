import Foundation

enum LLMTemperature {
    static func normalized(_ value: Double) -> Double {
        (min(max(value, 0), 2) * 10).rounded() / 10
    }
}

enum LLMProvider: String, CaseIterable, Identifiable, Sendable {
    case anthropic
    case openAI = "openai"
    case gemini
    case kimi
    case openRouter = "openrouter"
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: "Anthropic"
        case .openAI: "OpenAI"
        case .gemini: "Gemini"
        case .kimi: "Kimi"
        case .openRouter: "OpenRouter"
        case .custom: "Compatible OpenAI"
        }
    }

    var keyCreationURL: URL? {
        switch self {
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")
        case .openAI: URL(string: "https://platform.openai.com/api-keys")
        case .gemini: URL(string: "https://aistudio.google.com/app/apikey")
        case .kimi: URL(string: "https://platform.moonshot.ai/console/api-keys")
        case .openRouter: URL(string: "https://openrouter.ai/settings/keys")
        case .custom: nil
        }
    }
}

struct LLMConfiguration: Sendable {
    let provider: LLMProvider
    let apiKey: String?
    let model: String
    let endpoint: URL?
    let temperature: Double

    static func fromBundle(_ bundle: Bundle = .main) -> LLMConfiguration {
        let configuredProvider = (bundle.object(forInfoDictionaryKey: "LLM_PROVIDER") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let provider = configuredProvider.flatMap(LLMProvider.init(rawValue:)) ?? .gemini
        let apiKey = bundle.object(forInfoDictionaryKey: "LLM_API_KEY") as? String
        let configuredModel = bundle.object(forInfoDictionaryKey: "LLM_MODEL") as? String
        let configuredEndpoint = bundle.object(forInfoDictionaryKey: "LLM_ENDPOINT") as? String
        let configuredTemperature = bundle.object(forInfoDictionaryKey: "LLM_TEMPERATURE") as? Double

        return LLMConfiguration(
            provider: provider,
            apiKey: apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
            model: configuredModel.flatMap { $0.isEmpty ? nil : $0 } ?? provider.defaultModel,
            endpoint: configuredEndpoint.flatMap(URL.init(string:)) ?? provider.defaultEndpoint,
            temperature: LLMTemperature.normalized(
                configuredTemperature ?? provider.requestTemperature
            )
        )
    }
}

extension LLMProvider {
    func acceptsMediumPhotoConfidence(model: String) -> Bool {
        switch self {
        case .anthropic, .openAI:
            true
        case .openRouter:
            model.lowercased().hasPrefix("anthropic/")
                || model.lowercased().hasPrefix("openai/")
        case .gemini, .kimi, .custom:
            false
        }
    }

    var analysisTimeout: TimeInterval {
        switch self {
        case .kimi: 240
        default: 90
        }
    }

    var requestTemperature: Double {
        1
    }

    var defaultModel: String {
        switch self {
        case .anthropic: "claude-sonnet-4-5"
        case .openAI: "gpt-4.1-mini"
        case .gemini: "gemini-3.6-flash"
        case .kimi: "kimi-k2.5"
        case .openRouter: "anthropic/claude-sonnet-4.5"
        case .custom: ""
        }
    }

    var defaultEndpoint: URL? {
        switch self {
        case .anthropic: URL(string: "https://api.anthropic.com/v1/messages")
        case .openAI: URL(string: "https://api.openai.com/v1/chat/completions")
        case .gemini: nil
        case .kimi: URL(string: "https://api.moonshot.ai/v1/chat/completions")
        case .openRouter: URL(string: "https://openrouter.ai/api/v1/chat/completions")
        case .custom: nil
        }
    }
}
