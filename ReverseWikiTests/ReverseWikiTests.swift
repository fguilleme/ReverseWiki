//
//  ReverseWikiTests.swift
//  ReverseWikiTests
//
//  Created by François Guillemé on 24/07/2026.
//

import CoreLocation
import CoreGraphics
import Foundation
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
        #expect(!ModelCatalogService.supportsImageInput(
            modelID: "gemini-2.5-flash-preview-tts",
            provider: .gemini
        ))
        #expect(!ModelCatalogService.supportsImageInput(
            modelID: "gemini-3-pro-image-preview",
            provider: .gemini
        ))
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
