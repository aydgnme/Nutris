//
//  MockFoodRecognitionService.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import Foundation
import UIKit

final class MockFoodRecognitionService: FoodRecognitionService {
    func recognize(image: UIImage) async throws -> RecognitionResult {
        try Task.checkCancellation()

        let mockResults = [
            "Grilled Chicken Salad",
            "Avocado Toast",
            "Spaghetti Bolognese",
            "Chocolate Cake"
        ]

        let recognizedFood = mockResults.randomElement() ?? "Unknown Food"

        try Task.checkCancellation()

        return RecognitionResult(recognizedFoodName: recognizedFood)
    }
}
