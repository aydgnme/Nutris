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
                
                if viewModel.isProcessing {
                    ProgressView("Analyzing...")
                        .progressViewStyle(.circular)
                        .tint(NutrisDesign.Color.primary)
                }
                
                RecognitionResultCard(
                    title: "Recognition Result",
                    resultText: viewModel.recognizedText
                )
                
                analyzeButton
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Scan Food")
    }
}

// MARK: - Components

private extension FoodScannerView {
    
    var analyzeButton: some View {
        Button {
            viewModel.analyzeSample()
        } label: {
            Text("Analyze Sample")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(NutrisDesign.Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}


#Preview {
    FoodScannerView()
}
