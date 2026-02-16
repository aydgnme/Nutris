//
//  FoodScannerViewModelTests.swift
//  NutrisTests
//
//  Created by Mert Aydogan on 16.02.2026.
//

import AVFoundation
@testable import Nutris
import UIKit
import XCTest

@MainActor
final class FoodScannerViewModelTests: XCTestCase {
    func test_startScanning_success() async {
        let viewModel = self.makeViewModel(
            recognitionService: SuccessRecognitionService(
                result: RecognitionResult(recognizedFoodName: "Avocado Toast")
            )
        )

        XCTAssertEqual(viewModel.state, .idle)

        viewModel.startScanning(with: UIImage())

        await self.flushTasks()

        XCTAssertEqual(
            viewModel.state,
            .success(RecognitionResult(recognizedFoodName: "Avocado Toast"))
        )
    }

    func test_startScanning_failure_setsRecognitionFailedError() async {
        let viewModel = self.makeViewModel(recognitionService: FailingRecognitionService())

        viewModel.startScanning(with: UIImage())

        await self.flushTasks()

        XCTAssertEqual(viewModel.state, .error(.recognitionFailed))
    }

    func test_setupCamera_permissionGranted_configuresAndStartsCamera() async {
        let cameraService = TestCameraService()
        let permissionManager = TestCameraPermissionManager(
            granted: true,
            status: .authorized
        )

        let viewModel = FoodScannerViewModel(
            recognitionService: SuccessRecognitionService(
                result: RecognitionResult(recognizedFoodName: "Result")
            ),
            cameraService: cameraService,
            permissionManager: permissionManager
        )

        await viewModel.setupCamera()

        XCTAssertTrue(viewModel.hasCameraPermission)
        XCTAssertTrue(viewModel.isCameraReady)
        XCTAssertFalse(viewModel.isPermissionDenied)
        XCTAssertEqual(viewModel.cameraSessionState, .running)

        XCTAssertEqual(cameraService.configureCallCount, 1)
        XCTAssertEqual(cameraService.startCallCount, 1)
    }

    func test_setupCamera_permissionRestricted_setsPermissionRestrictedError() async {
        let cameraService = TestCameraService()
        let permissionManager = TestCameraPermissionManager(
            granted: false,
            status: .restricted
        )

        let viewModel = FoodScannerViewModel(
            recognitionService: SuccessRecognitionService(
                result: RecognitionResult(recognizedFoodName: "Result")
            ),
            cameraService: cameraService,
            permissionManager: permissionManager
        )

        await viewModel.setupCamera()

        XCTAssertFalse(viewModel.hasCameraPermission)
        XCTAssertFalse(viewModel.isCameraReady)
        XCTAssertFalse(viewModel.isPermissionDenied)

        XCTAssertEqual(viewModel.state, .error(.permissionRestricted))

        XCTAssertEqual(cameraService.configureCallCount, 0)
        XCTAssertEqual(cameraService.startCallCount, 0)
    }

    func test_captureAndScan_withoutFrame_setsNoFrameDomainError() async {
        let cameraService = TestCameraService()
        cameraService.frameToCapture = nil

        let viewModel = FoodScannerViewModel(
            recognitionService: SuccessRecognitionService(
                result: RecognitionResult(recognizedFoodName: "Result")
            ),
            cameraService: cameraService,
            permissionManager: TestCameraPermissionManager(
                granted: true,
                status: .authorized
            )
        )

        await viewModel.setupCamera()
        viewModel.captureAndScan()
        await self.flushTasks()

        XCTAssertEqual(viewModel.state, .error(.noFrameAvailable))
    }

    func test_handleDisappear_cancelsScanAndStopsCamera() async {
        let startedExpectation = expectation(description: "Recognition started")
        let recognitionService = ControlledRecognitionService {
            startedExpectation.fulfill()
        }

        let cameraService = TestCameraService()

        let viewModel = FoodScannerViewModel(
            recognitionService: recognitionService,
            cameraService: cameraService,
            permissionManager: TestCameraPermissionManager(
                granted: true,
                status: .authorized
            )
        )

        viewModel.startScanning(with: UIImage())

        await fulfillment(of: [startedExpectation], timeout: 1.0)

        await viewModel.handleDisappear()
        await self.flushTasks()

        XCTAssertEqual(cameraService.stopCallCount, 1)
        await XCTAssertEqual(recognitionService.cancellationCount(), 1)
    }

    func test_sessionInterruption_setsCameraStateCorrectly() async {
        let cameraService = TestCameraService()

        let viewModel = FoodScannerViewModel(
            recognitionService: SuccessRecognitionService(
                result: RecognitionResult(recognizedFoodName: "Result")
            ),
            cameraService: cameraService,
            permissionManager: TestCameraPermissionManager(
                granted: true,
                status: .authorized
            )
        )

        await viewModel.setupCamera()
        XCTAssertEqual(viewModel.cameraSessionState, .running)
        XCTAssertTrue(viewModel.isCameraReady)

        cameraService.simulate(sessionState: .interrupted)
        await self.flushTasks()

        XCTAssertEqual(viewModel.cameraSessionState, .interrupted)
        XCTAssertFalse(viewModel.isCameraReady)
    }

    func test_backgroundToForeground_resumesCameraState() async {
        let cameraService = TestCameraService()

        let viewModel = FoodScannerViewModel(
            recognitionService: SuccessRecognitionService(
                result: RecognitionResult(recognizedFoodName: "Result")
            ),
            cameraService: cameraService,
            permissionManager: TestCameraPermissionManager(
                granted: true,
                status: .authorized
            )
        )

        await viewModel.setupCamera()
        XCTAssertTrue(viewModel.isCameraReady)

        cameraService.simulate(sessionState: .stopped)
        await self.flushTasks()

        XCTAssertEqual(viewModel.cameraSessionState, .stopped)
        XCTAssertFalse(viewModel.isCameraReady)

        cameraService.simulate(sessionState: .running)
        await self.flushTasks()

        XCTAssertEqual(viewModel.cameraSessionState, .running)
        XCTAssertTrue(viewModel.isCameraReady)
    }

    func test_cancellationPreventsResultPublishing() async {
        let startedExpectation = expectation(description: "Recognition started")
        let recognitionService = NonCooperativeRecognitionService {
            startedExpectation.fulfill()
        }

        let viewModel = self.makeViewModel(recognitionService: recognitionService)

        viewModel.startScanning(with: UIImage())

        await fulfillment(of: [startedExpectation], timeout: 1.0)

        await viewModel.handleDisappear()

        await recognitionService.complete(
            with: RecognitionResult(recognizedFoodName: "Should Not Publish")
        )

        await self.flushTasks()

        if case .success = viewModel.state {
            XCTFail("Cancelled scan should not publish success state")
        }
    }

    func test_recognitionCancellation_propagatesFromViewModelTask() async {
        let startedExpectation = expectation(description: "Recognition started")
        let recognitionService = ControlledRecognitionService {
            startedExpectation.fulfill()
        }

        let viewModel = self.makeViewModel(recognitionService: recognitionService)

        viewModel.startScanning(with: UIImage())

        await fulfillment(of: [startedExpectation], timeout: 1.0)

        await viewModel.handleDisappear()
        await self.flushTasks()

        await XCTAssertEqual(recognitionService.cancellationCount(), 1)
    }

    private func makeViewModel(
        recognitionService: any FoodRecognitionService
    ) -> FoodScannerViewModel {
        let cameraService = TestCameraService()

        FoodScannerViewModel(
            recognitionService: recognitionService,
            cameraService: cameraService,
            permissionManager: TestCameraPermissionManager(
                granted: true,
                status: .authorized
            )
        )
    }

    private func flushTasks() async {
        await Task.yield()
        await Task.yield()
        await Task.yield()
    }
}
