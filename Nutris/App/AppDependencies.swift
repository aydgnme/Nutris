//
//  AppDependencies.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import Foundation

@MainActor struct AppDependencies {
    let recognitionService: any FoodRecognitionService
    let cameraService: any CameraServicing
    let permissionManager: any CameraPermissionManaging

    init(
        recognitionService: any FoodRecognitionService = RealFoodRecognitionService(),
        cameraService: (any CameraServicing)? = nil,
        permissionManager: any CameraPermissionManaging = CameraPermissionManager()
    ) {
        self.recognitionService = recognitionService
        self.cameraService = cameraService ?? CameraService()
        self.permissionManager = permissionManager
    }

    @MainActor
    func makeFoodScannerViewModel() -> FoodScannerViewModel {
        FoodScannerViewModel(
            recognitionService: self.recognitionService,
            cameraService: self.cameraService,
            permissionManager: self.permissionManager
        )
    }

    static var preview: AppDependencies {
        AppDependencies(recognitionService: MockFoodRecognitionService())
    }
}
