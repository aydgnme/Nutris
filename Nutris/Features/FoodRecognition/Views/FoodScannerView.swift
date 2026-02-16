//
//  FoodScannerView.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import SwiftUI

struct FoodScannerView: View {
    
    @State private var recognizedText: String = "No food detected yet."
    @State private var isProcessing: Bool = false
    
    var body: some View {
        ZStack {
            NutrisDesign.Color.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                
                CameraPreviewPlaceholder()
                
                if isProcessing {
                    ProgressView("Analyzing...")
                        .progressViewStyle(.circular)
                        .tint(NutrisDesign.Color.primary)
                }
                
                RecognitionResultCard(
                    title: "Recognition Result",
                    resultText: recognizedText
                )
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Scan Food")
    }
}

#Preview {
    FoodScannerView()
}
