//
//  CameraPreviewPlaceholder.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import SwiftUI

struct CameraPreviewPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(NutrisDesign.Color.surface)
            .frame(height: 320)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 40))
                        .foregroundStyle(NutrisDesign.Color.borderSoft)
                    
                    Text("Camera preview will appear here")
                        .font(.subheadline)
                        .foregroundStyle(NutrisDesign.Color.textPrimary.opacity(0.6))
                }
            )
            .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

#Preview {
    CameraPreviewPlaceholder()
}
