import Foundation
import ImageIO
import OSLog

enum LLMDiagnostics {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ReverseWiki",
        category: "LLMExchange"
    )

    static func logRequest(
        id: UUID,
        configuration: LLMConfiguration,
        imageData: Data,
        systemPrompt: String,
        userPrompt: String
    ) {
#if DEBUG
        let dimensions = imageDimensions(imageData)
        logger.info(
            """
            [\(id.uuidString, privacy: .public)] LLM request
            provider=\(configuration.provider.rawValue, privacy: .public)
            model=\(configuration.model, privacy: .public)
            temperature=\(configuration.temperature)
            timeout=\(configuration.provider.analysisTimeout)s
            imageBytes=\(imageData.count)
            imagePixels=\(dimensions, privacy: .public)
            systemPrompt=\(systemPrompt, privacy: .public)
            userPrompt=\(userPrompt, privacy: .public)
            """
        )
#endif
    }

    static func logResponse(
        id: UUID,
        configuration: LLMConfiguration,
        startedAt: ContinuousClock.Instant,
        data: Data,
        text: String,
        stopReason: String? = nil
    ) {
#if DEBUG
        let elapsed = startedAt.duration(to: .now)
        logger.info(
            """
            [\(id.uuidString, privacy: .public)] LLM response
            provider=\(configuration.provider.rawValue, privacy: .public)
            model=\(configuration.model, privacy: .public)
            totalDuration=\(String(describing: elapsed), privacy: .public)
            responseBytes=\(data.count)
            responseCharacters=\(text.count)
            stopReason=\(stopReason ?? "unknown", privacy: .public)
            response=\(text, privacy: .public)
            """
        )
#endif
    }

    static func logDecoded(id: UUID, fact: PlaceFact) {
#if DEBUG
        let encoded = (try? JSONEncoder().encode(fact))
            .map { String(decoding: $0, as: UTF8.self) }
            ?? "encoding-failed"
        logger.info(
            "[\(id.uuidString, privacy: .public)] Decoded PlaceFact=\(encoded, privacy: .public)"
        )
#endif
    }

    private static func imageDimensions(_ data: Data) -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return "unknown"
        }
        return "\(width.intValue)x\(height.intValue)"
    }
}
