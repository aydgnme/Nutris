//
//  FoodScannerViewModel.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import AVFoundation
import CoreImage
import Foundation
import Observation
import UIKit

// MARK: - State

enum FoodScannerViewState: Equatable {
    case idle
    case processing
    case success(String)
    case error(String)
}

@MainActor
@Observable
final class FoodScannerViewModel {
    private(set) var state: FoodScannerViewState = .idle
    private(set) var hasCameraPermission = false
    private(set) var isPermissionDenied = false
    private(set) var isCameraReady = false

    var cameraSession: AVCaptureSession {
        self.cameraService.session
    }

    var appSettingsURL: URL? {
        self.permissionManager.appSettingsURL
    }

    private let recognitionService: FoodRecognitionService
    private let cameraService: CameraServicing
    private let permissionManager: CameraPermissionManaging
    private let ciContext = CIContext()

    private var scanningTask: Task<Void, Never>?
    private var activeScanID = UUID()

    init(
        recognitionService: FoodRecognitionService,
        cameraService: CameraServicing = CameraService(),
        permissionManager: CameraPermissionManaging = CameraPermissionManager()
    ) {
        self.recognitionService = recognitionService
        self.cameraService = cameraService
        self.permissionManager = permissionManager
    }

    func setupCamera() async {
        let granted = await permissionManager.requestPermission()
        self.hasCameraPermission = granted

        let status = self.permissionManager.currentAuthorizationStatus()
        self.isPermissionDenied = !granted && status != .notDetermined

        guard granted else {
            self.isCameraReady = false
            return
        }

        do {
            try await self.cameraService.configure()
            await self.cameraService.start()
            self.isCameraReady = true
        } catch {
            self.isCameraReady = false
            self.state = .error(Self.cameraSetupFailedMessage)
        }
    }

    func handleDisappear() async {
        self.scanningTask?.cancel()
        await self.cameraService.stop()
    }

    func captureAndScan() {
        guard self.hasCameraPermission else {
            self.state = .error(Self.permissionRequiredMessage)
            return
        }

        guard
            let pixelBuffer = cameraService.latestFramePixelBuffer(),
            let image = self.makeUIImage(from: pixelBuffer)
        else {
            self.state = .error(Self.noFrameMessage)
            return
        }

        self.startScanning(with: image)
    }

    func startScanning(with image: UIImage) {
        self.scanningTask?.cancel()
        self.state = .processing

        let scanID = UUID()
        self.activeScanID = scanID

        self.scanningTask = Task { [weak self] in
            guard let self else { return }

            defer {
                if self.activeScanID == scanID {
                    self.scanningTask = nil
                }
            }

            do {
                let result = try await self.recognitionService.recognizeFood(from: image)
                try Task.checkCancellation()

                guard self.activeScanID == scanID else { return }
                self.state = .success(result)
            } catch is CancellationError {
                return
            } catch {
                guard self.activeScanID == scanID else { return }
                self.state = .error(Self.recognitionFailedMessage)
            }
        }
    }

    func reset() {
        self.scanningTask?.cancel()
        self.scanningTask = nil
        self.activeScanID = UUID()
        self.state = .idle
    }
}

private extension FoodScannerViewModel {
    static let cameraSetupFailedMessage = "Unable to start the camera. Please try again."
    static let permissionRequiredMessage = "Camera access is required to scan food."
    static let noFrameMessage = "No frame available yet. Hold steady and try again."
    static let recognitionFailedMessage = "We couldn't recognize this item. Try again with better lighting."

    func makeUIImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
