//
//  FoodRecognitionService.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import Foundation
import UIKit

struct RecognitionResult: Equatable, Sendable {
    let recognizedFoodName: String
}

protocol FoodRecognitionService: Sendable {
    /// Performs food recognition for the provided image.
    ///
    /// Implementations must respect cooperative cancellation:
    /// check cancellation before expensive work and throw `CancellationError`
    /// when cancellation is detected.
    func recognize(image: UIImage) async throws -> RecognitionResult
}
