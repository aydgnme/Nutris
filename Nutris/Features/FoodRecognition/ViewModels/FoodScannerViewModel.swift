//
//  FoodScannerViewModel.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import Foundation
import Observation
import UIKit

// MARK: - State

enum FoodScannerViewState: Equatable {
    case idle
    case processing
    case success(String)
    case error(String)
}

@MainActor @Observable
final class FoodScannerViewModel {
    
    // MARK: - Properties

    var state: FoodScannerViewState = .idle

    private let recognitionService: FoodRecognitionService
    private var scanningTask: Task<Void, Never>?

    init(recognitionService: FoodRecognitionService) {
        self.recognitionService = recognitionService
    }

    // MARK: - Actions

    func startScanning(with image: UIImage) {
        
        // Cancel previous task if exists
        scanningTask?.cancel()
        
        state = .processing
        
        scanningTask = Task {
            do {
                let  result = try await recognitionService.recognizeFood(from: image)
                
                // Check cancellation before updating state
                guard !Task.isCancelled else { return }
                
                state = .success(result)
                
            } catch {
                guard !Task.isCancelled else { return }
                state = .error("Recognition failed.")
            }
        }
    }
    func reset() {
        scanningTask?.cancel()
        self.state = .idle
    }
}

