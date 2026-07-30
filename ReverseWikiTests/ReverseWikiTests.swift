//
//  ReverseWikiTests.swift
//  ReverseWikiTests
//
//  Created by François Guillemé on 24/07/2026.
//

import CoreLocation
import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import ReverseWiki

struct ReverseWikiTests {

    @Test func coordinateKeyRoundsToFourDecimals() {
        let coordinate = CLLocationCoordinate2D(latitude: 48.8583701, longitude: 2.2944813)
        let key = CoreDataFactCache.coordinateKey(
            for: coordinate,
            imageData: Data("cascade".utf8),
            cacheIdentifier: "gemini:gemini-flash"
        )
        #expect(key.contains(":48.8584,2.2945:"))
    }

    @Test func cacheKeyChangesWithModel() {
        let image = Data("cascade".utf8)
        let first = CoreDataFactCache.coordinateKey(
            for: nil,
            imageData: image,
            cacheIdentifier: "gemini:gemini-flash"
        )
        let second = CoreDataFactCache.coordinateKey(
            for: nil,
            imageData: image,
            cacheIdentifier: "openai:gpt-4.1-mini"
        )
        #expect(first != second)
    }

    @Test func modelCatalogFiltersTextOnlyModels() {
        #expect(ModelCatalogService.supportsImageInput(
            modelID: "gpt-4.1-mini",
            provider: .openAI
        ))
        #expect(!ModelCatalogService.supportsImageInput(
            modelID: "gpt-3.5-turbo",
            provider: .openAI
        ))
        #expect(ModelCatalogService.supportsImageInput(
            modelID: "kimi-k2.5",
            provider: .kimi
        ))
        #expect(!ModelCatalogService.supportsImageInput(
            modelID: "kimi-k2",
            provider: .kimi
        ))
        #expect(ModelCatalogService.supportsImageInput(
            modelID: "kimi-k2.6",
            provider: .kimi
        ))
        #expect(ModelCatalogService.supportsImageInput(
            modelID: "kimi-k3",
            provider: .kimi
        ))
        #expect(!ModelCatalogService.supportsImageInput(
            modelID: "kimi-k2.7-code",
            provider: .kimi
        ))
        #expect(!ModelCatalogService.supportsImageInput(
            modelID: "kimi-k2.7-code-highspeed",
            provider: .kimi
        ))
        #expect(!ModelCatalogService.supportsImageInput(
            modelID: "gemini-2.5-flash-preview-tts",
            provider: .gemini
        ))
        #expect(!ModelCatalogService.supportsImageInput(
            modelID: "gemini-3-pro-image-preview",
            provider: .gemini
        ))
    }

    @Test func kimiUsesRequiredTemperature() {
        #expect(LLMProvider.kimi.requestTemperature == 1)
        #expect(LLMProvider.openAI.requestTemperature == 0.2)
        #expect(LLMProvider.openRouter.requestTemperature == 0.2)
    }

    @Test func kimiAllowsLongMultimodalAnalysis() {
        #expect(LLMProvider.kimi.analysisTimeout == 240)
        #expect(LLMProvider.openAI.analysisTimeout == 90)
    }

    @Test func temperatureIsNormalizedForAPIsRequiringExactValues() {
        #expect(LLMTemperature.normalized(0.999999999999) == 1)
        #expect(LLMTemperature.normalized(1.000000000001) == 1)
        #expect(LLMTemperature.normalized(0.24) == 0.2)
    }

    @Test func resultDisplaysProviderAndModel() {
        let result = CaptureResult(
            imageData: Data(),
            coordinate: nil,
            fact: PlaceFact(
                lieu: "Lieu",
                faitOfficiel: "Récit",
                faitVerifie: "Fait",
                sources: [],
                latitude: nil,
                longitude: nil
            ),
            modelIdentifier: "gemini:gemini-3.6-flash"
        )
        #expect(result.modelDisplayName == "Gemini · gemini-3.6-flash")
    }

    @Test @MainActor func pdfExportCreatesPaginatedDocument() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600)).image { context in
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
        }
        let result = CaptureResult(
            imageData: try #require(image.jpegData(compressionQuality: 0.9)),
            coordinate: nil,
            fact: PlaceFact(
                lieu: "Tour de test",
                faitOfficiel: String(repeating: "Récit complet. ", count: 80),
                faitVerifie: String(repeating: "Fait vérifié. ", count: 80),
                sources: ["https://example.org/source"],
                latitude: nil,
                longitude: nil
            ),
            modelIdentifier: "gemini:gemini-3.6-flash"
        )

        let url = try await PDFExportService.makePDF(for: result)
        defer { try? FileManager.default.removeItem(at: url) }
        let document = try #require(CGPDFDocument(url as CFURL))
        #expect(document.numberOfPages >= 2)
    }

    @Test @MainActor func landscapePhotoFitsPortraitResultView() throws {
        let photo = UIGraphicsImageRenderer(
            size: CGSize(width: 1_600, height: 900)
        ).image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_600, height: 900))
        }
        let result = CaptureResult(
            imageData: try #require(photo.jpegData(compressionQuality: 0.9)),
            coordinate: nil,
            fact: PlaceFact(
                lieu: "Lac Atitlán, Guatemala",
                faitOfficiel: String(repeating: "Un récit touristique très détaillé. ", count: 12),
                faitVerifie: String(repeating: "Une vérification historique particulièrement longue. ", count: 20),
                sources: ["https://example.org/a-very-long-source-address"],
                latitude: nil,
                longitude: nil
            ),
            modelIdentifier: "gemini:gemini-3.6-flash"
        )
        let viewport = CGSize(width: 393, height: 852)
        let renderer = ImageRenderer(content: ResultView(
            result: result,
            onRestart: {},
            showsRestart: false
        ).frame(width: viewport.width, height: viewport.height))
        renderer.scale = 1
        let image = try #require(renderer.uiImage)
        #expect(image.size == viewport)
    }

    @Test @MainActor func analysisImageIsActuallyLimitedTo1600Pixels() throws {
        let source = UIGraphicsImageRenderer(
            size: CGSize(width: 3_840, height: 2_160)
        ).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3_840, height: 2_160))
        }
        let data = try #require(source.normalizedJPEGData())
        let normalized = try #require(UIImage(data: data))
        #expect(normalized.size.width == 1_600)
        #expect(normalized.size.height == 900)
    }

    @Test func anthropicRequestContainsImageAndTextBlocks() throws {
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let configuration = LLMConfiguration(
            provider: .anthropic,
            apiKey: "test-key",
            model: "claude-test",
            endpoint: URL(string: "https://example.org/messages"),
            temperature: 0.2
        )
        let client = AnthropicClient(session: .shared, configuration: configuration)
        let body = try client.requestBody(
            imageData: imageData,
            systemPrompt: "system",
            userPrompt: "user"
        )
        let json = try #require(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let messages = try #require(json["messages"] as? [[String: Any]])
        let content = try #require(messages.first?["content"] as? [[String: Any]])
        #expect(content.map { $0["type"] as? String } == ["image", "text"])
        let source = try #require(content.first?["source"] as? [String: Any])
        #expect(source["type"] as? String == "base64")
        #expect(source["media_type"] as? String == "image/jpeg")
        #expect(source["data"] as? String == imageData.base64EncodedString())
        #expect(content.last?["text"] as? String == "user")
    }

    @Test func placeFactDecodesStructuredContract() throws {
        let json = """
        {"lieu":"Tour Eiffel","fait_officiel":"Un symbole.","fait_verifie":"Elle devait être temporaire.","sources":["https://example.org"],"latitude":48.8584,"longitude":2.2945}
        """
        let fact = try JSONDecoder().decode(PlaceFact.self, from: Data(json.utf8))
        #expect(fact.lieu == "Tour Eiffel")
        #expect(fact.sources.count == 1)
        #expect(fact.identifiedCoordinate?.latitude == 48.8584)
    }
}
