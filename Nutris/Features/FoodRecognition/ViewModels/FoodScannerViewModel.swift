//
//  FoodScannerViewModel.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import Foundation
import Observation

@Observable
final class FoodScannerViewModel {
    
    // MARK: - State
    
    var recognizedText: String = "No food detected yet"
    var isProcessing: Bool = false
    
    // MARK: - Intent
    
    func analyzeSample() {
        isProcessing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.recognizedText = "Grilled Chicken Salad"
            self.isProcessing = false
        }
    }
}
