//
//  ContentView.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import SwiftUI

struct ContentView: View {
    private let viewModel: FoodScannerViewModel

    init(dependencies: AppDependencies) {
        self.viewModel = dependencies.makeFoodScannerViewModel()
    }

    var body: some View {
        FoodScannerView(viewModel: self.viewModel)
    }
}

#Preview {
    ContentView(dependencies: .preview)
}
