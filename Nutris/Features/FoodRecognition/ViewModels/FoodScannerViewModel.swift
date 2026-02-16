//
//  FoodScannerViewModel.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

@preconcurrency import AVFoundation
import Foundation
import Observation
import UIKit
import VideoToolbox

// MARK: - Domain Errors

enum FoodScannerError: Error, Equatable {
    case permissionDenied
    case permissionRestricted
    case cameraConfigurationFailed
    case noFrameAvailable
    case recognitionFailed
    case unknown(Error)

    static func == (lhs: FoodScannerError, rhs: FoodScannerError) -> Bool {
        switch (lhs, rhs) {
        case (.permissionDenied, .permissionDenied),
             (.permissionRestricted, .permissionRestricted),
             (.cameraConfigurationFailed, .cameraConfigurationFailed),
             (.noFrameAvailable, .noFrameAvailable),
             (.recognitionFailed, .recognitionFailed):
            return true

        case let (.unknown(lhsError), .unknown(rhsError)):
            let lhsNSError = lhsError as NSError
            let rhsNSError = rhsError as NSError

            return lhsNSError.domain == rhsNSError.domain && lhsNSError.code == rhsNSError.code

        default:
            return false
        }
    }
}

// MARK: - State

enum FoodScannerViewState: Equatable {
    case idle
    case processing
    case success(RecognitionResult)
    case error(FoodScannerError)
}

@MainActor
@Observable
final class FoodScannerViewModel {
    private(set) var state: FoodScannerViewState = .idle
    private(set) var hasCameraPermission = false
    private(set) var isPermissionDenied = false
    private(set) var isCameraReady = false
    private(set) var cameraSessionState: CameraSessionState = .stopped
    private(set) var cameraSession: AVCaptureSession?

    var appSettingsURL: URL? {
        self.permissionManager.appSettingsURL
    }

    private let recognitionService: any FoodRecognitionService
    private let cameraService: any CameraServicing
    private let permissionManager: any CameraPermissionManaging

    private var scanningTask: Task<Void, Never>?
    private var sessionStateTask: Task<Void, Never>?
    private var activeScanID = UUID()

    init(
        recognitionService: any FoodRecognitionService,
        cameraService: any CameraServicing,
        permissionManager: any CameraPermissionManaging
    ) {
        self.recognitionService = recognitionService
        self.cameraService = cameraService
        self.permissionManager = permissionManager

        self.observeSessionState()
    }

    func setupCamera() async {
        if self.cameraSession == nil {
            self.cameraSession = await self.cameraService.previewSession
        }

        let granted = await self.permissionManager.requestPermission()
        self.hasCameraPermission = granted

        let status = self.permissionManager.currentAuthorizationStatus()
        self.isPermissionDenied = !granted && status == .denied

        guard granted else {
            self.isCameraReady = false
            self.cameraSessionState = await self.cameraService.sessionState
            self.state = .error(self.permissionError(for: status))
            return
        }

        do {
            try await self.cameraService.configure()
            await self.cameraService.start()

            self.cameraSessionState = await self.cameraService.sessionState
            self.isCameraReady = self.cameraSessionState == .running

            if case .error = self.state {
                self.state = .idle
            }
        } catch CameraServiceError.configurationFailed {
            self.isCameraReady = false
            self.state = .error(.cameraConfigurationFailed)
        } catch {
            self.isCameraReady = false
            self.state = .error(.unknown(error))
        }
    }

    func handleDisappear() async {
        self.scanningTask?.cancel()
        self.scanningTask = nil
        self.activeScanID = UUID()

        await self.cameraService.stop()
    }

    func captureAndScan() {
        Task { [weak self] in
            guard let self else {
                return
            }

            await self.captureAndScanInternal()
        }
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
                let result = try await self.recognitionService.recognize(image: image)
                try Task.checkCancellation()

                guard self.activeScanID == scanID else {
                    return
                }

                self.state = .success(result)
            } catch is CancellationError {
                return
            } catch let scannerError as FoodScannerError {
                guard self.activeScanID == scanID else {
                    return
                }

                self.state = .error(scannerError)
            } catch {
                guard self.activeScanID == scanID else {
                    return
                }

                self.state = .error(.recognitionFailed)
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
    func observeSessionState() {
        self.sessionStateTask?.cancel()

        self.sessionStateTask = Task { [weak self] in
            guard let self else {
                return
            }

            let sessionStateStream = await self.cameraService.makeSessionStateStream()

            for await sessionState in sessionStateStream {
                guard !Task.isCancelled else {
                    return
                }

                self.cameraSessionState = sessionState
                self.isCameraReady = self.hasCameraPermission && sessionState == .running
            }
        }
    }

    func captureAndScanInternal() async {
        guard self.hasCameraPermission else {
            let status = self.permissionManager.currentAuthorizationStatus()
            self.state = .error(self.permissionError(for: status))
            return
        }

        guard let pixelBuffer = await self.cameraService.latestFramePixelBuffer() else {
            self.state = .error(.noFrameAvailable)
            return
        }

        guard let image = self.makeUIImage(from: pixelBuffer) else {
            self.state = .error(.recognitionFailed)
            return
        }

        self.startScanning(with: image)
    }

    func permissionError(for status: AVAuthorizationStatus) -> FoodScannerError {
        switch status {
        case .restricted:
            .permissionRestricted

        default:
            .permissionDenied
        }
    }

    func makeUIImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        var cgImage: CGImage?

        let status = VTCreateCGImageFromCVPixelBuffer(
            pixelBuffer,
            options: nil,
            imageOut: &cgImage
        )

        guard status == noErr, let cgImage else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
