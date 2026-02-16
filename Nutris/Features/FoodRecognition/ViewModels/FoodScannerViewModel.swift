//
//  FoodScannerViewModel.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import Foundation
import Observation
import UIKit

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

    private let recognitionService: FoodRecognitionService

    init(recognitionService: FoodRecognitionService) {
        self.recognitionService = recognitionService
    }

    // MARK: - Actions

    func startScanning(with image: UIImage) {
        self.state = .processing

        Task {
            do {
                let result = try await recognitionService.recognizeFood(from: image)
                self.state = .success(result)
            } catch {
                self.state = .error("Recognition failed.")
            }
        }
    }

    func reset() {
        self.state = .idle
    }
}
