//
//  FoodScannerTestDoubles.swift
//  NutrisTests
//
//  Created by Mert Aydogan on 16.02.2026.
//

import AVFoundation
import CoreVideo
import Foundation
@testable import Nutris
import UIKit

struct SuccessRecognitionService: FoodRecognitionService {
    let result: RecognitionResult

    func recognize(image: UIImage) async throws -> RecognitionResult {
        self.result
    }
}

struct FailingRecognitionService: FoodRecognitionService {
    struct TestError: Error {}

    func recognize(image: UIImage) async throws -> RecognitionResult {
        throw TestError()
    }
}

actor ControlledRecognitionGate {
    private var continuation: CheckedContinuation<RecognitionResult, Error>?
    private var cancellationCount = 0

    func waitForResult() async throws -> RecognitionResult {
        try Task.checkCancellation()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        } onCancel: {
            Task {
                await self.cancelCurrentRequest()
            }
        }
    }

    func complete(with result: RecognitionResult) {
        self.continuation?.resume(returning: result)
        self.continuation = nil
    }

    func cancellationCountValue() -> Int {
        self.cancellationCount
    }

    private func cancelCurrentRequest() {
        self.cancellationCount += 1
        self.continuation?.resume(throwing: CancellationError())
        self.continuation = nil
    }
}

final class ControlledRecognitionService: @unchecked Sendable, FoodRecognitionService {
    private let gate = ControlledRecognitionGate()
    private let onStart: @Sendable () -> Void

    init(onStart: @escaping @Sendable () -> Void = {}) {
        self.onStart = onStart
    }

    func recognize(image: UIImage) async throws -> RecognitionResult {
        self.onStart()
        return try await self.gate.waitForResult()
    }

    func complete(with result: RecognitionResult) async {
        await self.gate.complete(with: result)
    }

    func cancellationCount() async -> Int {
        await self.gate.cancellationCountValue()
    }
}

actor NonCooperativeRecognitionGate {
    private var continuation: CheckedContinuation<RecognitionResult, Never>?

    func waitForResult() async -> RecognitionResult {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func complete(with result: RecognitionResult) {
        self.continuation?.resume(returning: result)
        self.continuation = nil
    }
}

final class NonCooperativeRecognitionService: @unchecked Sendable, FoodRecognitionService {
    private let gate = NonCooperativeRecognitionGate()
    private let onStart: @Sendable () -> Void

    init(onStart: @escaping @Sendable () -> Void = {}) {
        self.onStart = onStart
    }

    func recognize(image: UIImage) async throws -> RecognitionResult {
        self.onStart()
        return await self.gate.waitForResult()
    }

    func complete(with result: RecognitionResult) async {
        await self.gate.complete(with: result)
    }
}

struct TestCameraPermissionManager: CameraPermissionManaging {
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

final class TestCameraService: @unchecked Sendable, CameraServicing {
    let session = AVCaptureSession()

    var previewSession: AVCaptureSession {
        get async {
            self.session
        }
    }

    var sessionState: CameraSessionState {
        get async {
            self.currentState
        }
    }

    var shouldThrowOnConfigure = false
    var configureCallCount = 0
    var startCallCount = 0
    var stopCallCount = 0
    var frameToCapture: CVPixelBuffer?

    private var currentState: CameraSessionState = .stopped
    private var streamContinuations: [UUID: AsyncStream<CameraSessionState>.Continuation] = [:]

    func configure() async throws {
        self.configureCallCount += 1

        if self.shouldThrowOnConfigure {
            throw CameraServiceError.configurationFailed
        }
    }

    func start() async {
        self.startCallCount += 1
        self.publish(sessionState: .running)
    }

    func stop() async {
        self.stopCallCount += 1
        self.publish(sessionState: .stopped)
    }

    func latestFramePixelBuffer() async -> CVPixelBuffer? {
        self.frameToCapture
    }

    func makeSessionStateStream() async -> AsyncStream<CameraSessionState> {
        AsyncStream { continuation in
            let streamID = UUID()
            self.streamContinuations[streamID] = continuation
            continuation.yield(self.currentState)

            continuation.onTermination = { [weak self] _ in
                self?.streamContinuations.removeValue(forKey: streamID)
            }
        }
    }

    func simulate(sessionState: CameraSessionState) {
        self.publish(sessionState: sessionState)
    }

    private func publish(sessionState: CameraSessionState) {
        self.currentState = sessionState

        for continuation in self.streamContinuations.values {
            continuation.yield(sessionState)
        }
    }
}
