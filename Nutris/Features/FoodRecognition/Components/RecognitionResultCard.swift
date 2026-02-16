//
//  RecognitionResultCard.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import SwiftUI

struct RecognitionResultCard: View {
    
    let title: String
    let resultText: String
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(NutrisDesign.Color.surface)
            .overlay(
                VStack(alignment: .leading, spacing: 8) {
                    
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(NutrisDesign.Color.textPrimary)
                    
                    Text(resultText)
                        .font(.body)
                        .foregroundStyle(NutrisDesign.Color.primary)
                }
                    .padding()
            )
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .shadow(color: .black.opacity(0.04), radius: 6)
    }
}

#Preview {
    RecognitionResultCard(title: "Test", resultText: "Test")
}
