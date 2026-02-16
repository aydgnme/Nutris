//
//  MockFoodRecognitionService.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import Foundation
import UIKit

final class MockFoodRecognitionService: FoodRecognitionService {
    func recognizeFood(from image: UIImage) async throws -> String {
        try await Task.sleep(for: .seconds(2))
        try Task.checkCancellation()

        let mockResult = [
            "Grilled Chicken Salad",
            "Avocado Toast",
            "Spaghetti Bolognese",
            "Chocolate Cake"
        ]

        return mockResult.randomElement() ?? "Unknown Food"
    }
}
