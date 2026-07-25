//
//  ReverseWikiTests.swift
//  ReverseWikiTests
//
//  Created by François Guillemé on 24/07/2026.
//

import CoreLocation
import Foundation
import Testing
@testable import ReverseWiki

struct ReverseWikiTests {

    @Test func coordinateKeyRoundsToFourDecimals() {
        let coordinate = CLLocationCoordinate2D(latitude: 48.8583701, longitude: 2.2944813)
        let key = CoreDataFactCache.coordinateKey(for: coordinate, imageData: Data("cascade".utf8))
        #expect(key.hasPrefix("vision-v4:48.8584,2.2945:"))
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
