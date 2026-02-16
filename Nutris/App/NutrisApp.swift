//
//  NutrisApp.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import SwiftUI

@main
struct NutrisApp: App {
    private let dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            ContentView(dependencies: self.dependencies)
        }
    }
}
