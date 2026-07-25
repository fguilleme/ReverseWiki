//
//  ReverseWikiApp.swift
//  ReverseWiki
//
//  Created by François Guillemé on 24/07/2026.
//

import SwiftUI

@main
struct ReverseWikiApp: App {
    private let dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            AppRootView(dependencies: dependencies)
        }
    }
}
