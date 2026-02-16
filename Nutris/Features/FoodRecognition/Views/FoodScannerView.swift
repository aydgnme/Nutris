//
//  FoodScannerView.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import SwiftUI

struct FoodScannerView: View {
    
    @State private var viewModel = FoodScannerViewModel()
    
    var body: some View {
        ZStack {
            NutrisDesign.Color.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                
                CameraPreviewPlaceholder()
                
                content
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Scan Food")
    }
}

// MARK: - State Rendering

private extension FoodScannerView {
    
    @ViewBuilder
    var content: some View {
        switch viewModel.state {
        case .idle:
            Button("Start Scan") {
                viewModel.startScanning()
            }
            .buttonStyle(.borderedProminent)
            .tint(NutrisDesign.Color.primary)
            
        case .processing:
            ProgressView("Analyzing...")
                .progressViewStyle(.circular)
                .tint(NutrisDesign.Color.primary)
            
        case .success(let result):
            RecognitionResultCard(
                title: "Recognition Result",
                resultText: result
            )
            
        case .error(let message):
            Text(message)
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    FoodScannerView()
}
