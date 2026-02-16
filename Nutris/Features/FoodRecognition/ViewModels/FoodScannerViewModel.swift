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
    
    enum ViewState: Equatable {
        case idle
        case processing
        case success(String)
        case error(String)
    }
    
    // MARK: - Properties
    
    var state: ViewState = .idle
    
    // MARK: - Actions
    
    func startScanning() {
        state = .processing
        
        Task {
            try? await Task.sleep(for: .seconds(2))
            
            // Temporary mock result
            let mockResult = "Grilled Chicken Salad"
            
            state = .success(mockResult)
        }
    }
    
    func reset() {
        state = .idle
    }
}
