//
//  FoodRecognitionService.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import Foundation
import UIKit

protocol FoodRecognitionService {
    func recognizeFood(from image: UIImage) async throws -> String
}
