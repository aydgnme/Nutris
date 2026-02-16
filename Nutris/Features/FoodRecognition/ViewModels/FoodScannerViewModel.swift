//
//  FoodScannerViewModel.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import Foundation
import Observation
import SwiftUI
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

    init(recognitionService: FoodRecognitionService) {
        self.recognitionService = recognitionService
    }

    // MARK: - Actions

    func startScanning(with image: UIImage) {
        self.state = .processing

        Task {
            do {
                // Perform recognition off the main actor
                let result = try await recognitionService.recognizeFood(from: image)
                // Hop back to main actor to update state explicitly
                await MainActor.run { [weak self] in
                    self?.state = .success(result)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.state = .error("Recognition failed.")
                }
            }
        }
    }

    func reset() {
        self.state = .idle
    }
}
