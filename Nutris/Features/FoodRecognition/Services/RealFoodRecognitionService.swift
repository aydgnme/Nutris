//
//  RealFoodRecognitionService.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import Foundation
import UIKit

struct RealFoodRecognitionService: FoodRecognitionService {
    func recognize(image: UIImage) async throws -> RecognitionResult {
        try Task.checkCancellation()

        // Stub until the Vision request pipeline is integrated in Sprint 2.
        // The production implementation should avoid redundant UIImage work
        // by consuming camera-frame buffers directly before model inference.
        return RecognitionResult(recognizedFoodName: "Recognition pipeline is initializing")
    }
}
