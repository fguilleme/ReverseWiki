import Foundation

enum LLMProvider: String, Sendable {
    case anthropic
    case openAI = "openai"
    case gemini
    case kimi
    case openRouter = "openrouter"
    case custom
}

struct LLMConfiguration: Sendable {
    let provider: LLMProvider
    let apiKey: String?
    let model: String
    let endpoint: URL?

    static func fromBundle(_ bundle: Bundle = .main) -> LLMConfiguration {
        let configuredProvider = (bundle.object(forInfoDictionaryKey: "LLM_PROVIDER") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let provider = configuredProvider.flatMap(LLMProvider.init(rawValue:)) ?? .gemini
        let apiKey = bundle.object(forInfoDictionaryKey: "LLM_API_KEY") as? String
        let configuredModel = bundle.object(forInfoDictionaryKey: "LLM_MODEL") as? String
        let configuredEndpoint = bundle.object(forInfoDictionaryKey: "LLM_ENDPOINT") as? String

        return LLMConfiguration(
            provider: provider,
            apiKey: apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
            model: configuredModel.flatMap { $0.isEmpty ? nil : $0 } ?? provider.defaultModel,
            endpoint: configuredEndpoint.flatMap(URL.init(string:)) ?? provider.defaultEndpoint
        )
    }
}

private extension LLMProvider {
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
