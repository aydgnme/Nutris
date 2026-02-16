//
//  FoodScannerViewModelTests.swift
//  NutrisTests
//
//  Created by Mert Aydogan on 16.02.2026.
//

import AVFoundation
import Foundation
@testable import Nutris
import UIKit
import XCTest

private final class TestFoodRecognitionService: FoodRecognitionService {
    var result: Result<String, Error>

    init(result: Result<String, Error>) {
        self.result = result
    }

    func recognizeFood(from image: UIImage) async throws -> String {
        try self.result.get()
    }
}

private struct TestCameraPermissionManager: CameraPermissionManaging {
    let granted: Bool
    let status: AVAuthorizationStatus

    var appSettingsURL: URL? {
        URL(string: "app-settings:")
    }

    func requestPermission() async -> Bool {
        self.granted
    }

    func currentAuthorizationStatus() -> AVAuthorizationStatus {
        self.status
    }
}

private final class TestCameraService: CameraServicing {
    let session = AVCaptureSession()

    var shouldThrowOnConfigure = false
    var configureCallCount = 0
    var startCallCount = 0
    var stopCallCount = 0
    var frameToCapture: UIImage?

    func configureIfNeeded() async throws {
        self.configureCallCount += 1
        if self.shouldThrowOnConfigure {
            throw CameraServiceError.configurationFailed
        }
    }

    func start() {
        self.startCallCount += 1
    }

    func stop() {
        self.stopCallCount += 1
    }

    func captureCurrentFrame() -> UIImage? {
        self.frameToCapture
    }
}

private actor RecognitionCounter {
    private var count = 0

    func next() -> Int {
        self.count += 1
        return self.count
    }
}

private final class DelayedFoodRecognitionService: FoodRecognitionService {
    private let counter = RecognitionCounter()

    func recognizeFood(from image: UIImage) async throws -> String {
        let callIndex = await counter.next()

        if callIndex == 1 {
            try await Task.sleep(for: .milliseconds(200))
            return "First Result"
        }

        return "Second Result"
    }
}

@MainActor
final class FoodScannerViewModelTests: XCTestCase {
    func test_startScanning_success() async {
        let mockService = TestFoodRecognitionService(
            result: .success("Avocado Toast")
        )
        let cameraService = TestCameraService()
        let permissionManager = TestCameraPermissionManager(
            granted: true,
            status: .authorized
        )

        let viewModel = FoodScannerViewModel(
            recognitionService: mockService,
            cameraService: cameraService,
            permissionManager: permissionManager
        )

        XCTAssertEqual(viewModel.state, .idle)

        viewModel.startScanning(with: UIImage())

        await self.flushTasks()

        XCTAssertEqual(viewModel.state, .success("Avocado Toast"))
    }

    func test_startScanning_failure() async {
        struct TestError: Error {}

        let mockService = TestFoodRecognitionService(
            result: .failure(TestError())
        )
        let cameraService = TestCameraService()
        let permissionManager = TestCameraPermissionManager(
            granted: true,
            status: .authorized
        )

        let viewModel = FoodScannerViewModel(
            recognitionService: mockService,
            cameraService: cameraService,
            permissionManager: permissionManager
        )

        viewModel.startScanning(with: UIImage())

        await self.flushTasks()

        if case let .error(message) = viewModel.state {
            XCTAssertEqual(
                message,
                "We couldn't recognize this item. Try again with better lighting."
            )
        } else {
            XCTFail("Expected error state")
        }
    }

    func test_setupCamera_permissionGranted_configuresAndStartsCamera() async {
        let cameraService = TestCameraService()
        let permissionManager = TestCameraPermissionManager(
            granted: true,
            status: .authorized
        )
        let viewModel = FoodScannerViewModel(
            recognitionService: TestFoodRecognitionService(result: .success("Result")),
            cameraService: cameraService,
            permissionManager: permissionManager
        )

        await viewModel.setupCamera()

        XCTAssertTrue(viewModel.hasCameraPermission)
        XCTAssertTrue(viewModel.isCameraReady)
        XCTAssertFalse(viewModel.isPermissionDenied)
        XCTAssertEqual(cameraService.configureCallCount, 1)
        XCTAssertEqual(cameraService.startCallCount, 1)
    }

    func test_setupCamera_permissionDenied_keepsCameraStopped() async {
        let cameraService = TestCameraService()
        let permissionManager = TestCameraPermissionManager(
            granted: false,
            status: .denied
        )
        let viewModel = FoodScannerViewModel(
            recognitionService: TestFoodRecognitionService(result: .success("Result")),
            cameraService: cameraService,
            permissionManager: permissionManager
        )

        await viewModel.setupCamera()

        XCTAssertFalse(viewModel.hasCameraPermission)
        XCTAssertFalse(viewModel.isCameraReady)
        XCTAssertTrue(viewModel.isPermissionDenied)
        XCTAssertEqual(cameraService.configureCallCount, 0)
        XCTAssertEqual(cameraService.startCallCount, 0)
    }

    func test_captureAndScan_withoutFrame_setsErrorState() async {
        let cameraService = TestCameraService()
        cameraService.frameToCapture = nil

        let permissionManager = TestCameraPermissionManager(
            granted: true,
            status: .authorized
        )
        let viewModel = FoodScannerViewModel(
            recognitionService: TestFoodRecognitionService(result: .success("Result")),
            cameraService: cameraService,
            permissionManager: permissionManager
        )

        await viewModel.setupCamera()
        viewModel.captureAndScan()

        if case let .error(message) = viewModel.state {
            XCTAssertEqual(message, "No frame available yet. Hold steady and try again.")
        } else {
            XCTFail("Expected no-frame error state")
        }
    }

    func test_startScanning_cancelsPreviousTask_andKeepsLatestResult() async throws {
        let service = DelayedFoodRecognitionService()
        let viewModel = FoodScannerViewModel(
            recognitionService: service,
            cameraService: TestCameraService(),
            permissionManager: TestCameraPermissionManager(
                granted: true,
                status: .authorized
            )
        )

        viewModel.startScanning(with: UIImage())
        viewModel.startScanning(with: UIImage())

        try await Task.sleep(for: .milliseconds(250))

        XCTAssertEqual(viewModel.state, .success("Second Result"))
    }

    private func flushTasks() async {
        await Task.yield()
        await Task.yield()
    }
}
