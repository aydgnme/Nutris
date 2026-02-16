//
//  CameraService.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import AVFoundation
import CoreVideo
import Foundation

enum CameraServiceError: Error {
    case configurationFailed
}

protocol CameraServicing: AnyObject {
    var session: AVCaptureSession { get }
    func configure() async throws
    func start() async
    func stop() async
    func latestFramePixelBuffer() -> CVPixelBuffer?
}

final class CameraService: NSObject, CameraServicing {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.nutris.camera.session")
    private let queueKey = DispatchSpecificKey<UInt8>()
    private let videoOutput = AVCaptureVideoDataOutput()

    private var isConfigured = false
    private var shouldRun = false
    private var isRunning = false
    private var isInBackground = false
    private var isSessionInterrupted = false
    private var latestPixelBuffer: CVPixelBuffer?

    override init() {
        super.init()
        self.sessionQueue.setSpecific(key: self.queueKey, value: 1)
        self.registerObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func configure() async throws {
        try self.performOnSessionQueue {
            guard !self.isConfigured else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            defer { self.session.commitConfiguration() }

            guard
                let device = AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: .back
                ),
                let input = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input),
                self.session.canAddOutput(self.videoOutput)
            else {
                throw CameraServiceError.configurationFailed
            }

            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            self.videoOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)

            self.session.addInput(input)
            self.session.addOutput(self.videoOutput)
            self.isConfigured = true
        }
    }

    func start() async {
        self.performOnSessionQueue {
            self.shouldRun = true
            self.startSessionIfPossible()
        }
    }

    func stop() async {
        self.performOnSessionQueue {
            self.shouldRun = false
            self.stopSessionIfNeeded()
        }
    }

    func latestFramePixelBuffer() -> CVPixelBuffer? {
        self.performOnSessionQueue {
            self.latestPixelBuffer
        }
    }
}

private extension CameraService {
    enum AppNotifications {
        static let didEnterBackground = Notification.Name("UIApplicationDidEnterBackgroundNotification")
        static let willEnterForeground = Notification.Name("UIApplicationWillEnterForegroundNotification")
    }

    func registerObservers() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: AppNotifications.didEnterBackground,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: AppNotifications.willEnterForeground,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleSessionWasInterrupted),
            name: AVCaptureSession.wasInterruptedNotification,
            object: self.session
        )
        center.addObserver(
            self,
            selector: #selector(handleSessionInterruptionEnded),
            name: AVCaptureSession.interruptionEndedNotification,
            object: self.session
        )
    }

    @objc func handleDidEnterBackground(_ notification: Notification) {
        self.performOnSessionQueue {
            self.isInBackground = true
            self.stopSessionIfNeeded()
        }
    }

    @objc func handleWillEnterForeground(_ notification: Notification) {
        self.performOnSessionQueue {
            self.isInBackground = false
            self.startSessionIfPossible()
        }
    }

    @objc func handleSessionWasInterrupted(_ notification: Notification) {
        self.performOnSessionQueue {
            self.isSessionInterrupted = true
            self.isRunning = false
        }
    }

    @objc func handleSessionInterruptionEnded(_ notification: Notification) {
        self.performOnSessionQueue {
            self.isSessionInterrupted = false
            self.startSessionIfPossible()
        }
    }

    func startSessionIfPossible() {
        guard
            self.shouldRun,
            self.isConfigured,
            !self.isInBackground,
            !self.isSessionInterrupted
        else {
            return
        }

        guard !self.session.isRunning else {
            self.isRunning = true
            return
        }

        self.session.startRunning()
        self.isRunning = self.session.isRunning
    }

    func stopSessionIfNeeded() {
        guard self.session.isRunning else {
            self.isRunning = false
            return
        }

        self.session.stopRunning()
        self.isRunning = false
    }

    func performOnSessionQueue<T>(_ work: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: self.queueKey) != nil {
            return try work()
        }
        return try self.sessionQueue.sync(execute: work)
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        self.latestPixelBuffer = pixelBuffer
    }
}
