//
//  CameraService.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

@preconcurrency import AVFoundation
import Foundation
import UIKit

enum CameraServiceError: Error {
    case configurationFailed
}

protocol CameraServicing: AnyObject {
    var session: AVCaptureSession { get }
    func configureIfNeeded() async throws
    func start()
    func stop()
    func captureCurrentFrame() -> UIImage?
}

actor CameraService: CameraServicing {
    nonisolated(unsafe) let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private nonisolated let latestFrameLock = NSLock()
    private nonisolated(unsafe) var latestFrame: UIImage?

    private var isConfigured = false
    private var isRunning = false
    private var framePumpTask: Task<Void, Never>?

    private var nextCaptureID = 0
    private var captureDelegates: [Int: PhotoCaptureDelegateBridge] = [:]

    func configureIfNeeded() async throws {
        guard !self.isConfigured else { return }

        self.session.beginConfiguration()
        self.session.sessionPreset = .photo
        defer { session.commitConfiguration() }

        guard
            let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            ),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input),
            session.canAddOutput(photoOutput)
        else {
            throw CameraServiceError.configurationFailed
        }

        self.session.addInput(input)
        self.session.addOutput(self.photoOutput)
        self.isConfigured = true
    }

    nonisolated func start() {
        Task {
            await self.startIfNeeded()
        }
    }

    nonisolated func stop() {
        Task {
            await self.stopIfNeeded()
        }
    }

    nonisolated func captureCurrentFrame() -> UIImage? {
        self.latestFrameLock.lock()
        let frame = self.latestFrame
        self.latestFrameLock.unlock()
        return frame
    }

    private func startIfNeeded() {
        guard self.isConfigured, !self.isRunning else { return }

        self.session.startRunning()
        self.isRunning = true
        self.startFramePumpIfNeeded()
    }

    private func stopIfNeeded() {
        guard self.isRunning else { return }

        self.isRunning = false
        self.framePumpTask?.cancel()
        self.framePumpTask = nil

        for delegate in self.captureDelegates.values {
            delegate.cancel()
        }
        self.captureDelegates.removeAll()

        if self.session.isRunning {
            self.session.stopRunning()
        }
    }

    private func startFramePumpIfNeeded() {
        guard self.framePumpTask == nil else { return }

        self.framePumpTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                guard await self.isRunning else { return }

                await self.capturePhotoFrame()

                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func capturePhotoFrame() async {
        guard self.isRunning else { return }

        let captureID = self.nextCaptureID
        self.nextCaptureID += 1

        let settings = AVCapturePhotoSettings()
        let image: UIImage? = await withCheckedContinuation { continuation in
            let delegate = PhotoCaptureDelegateBridge(continuation: continuation)
            self.captureDelegates[captureID] = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }

        self.captureDelegates[captureID] = nil
        self.setLatestFrame(image)
    }

    private func setLatestFrame(_ image: UIImage?) {
        self.latestFrameLock.lock()
        self.latestFrame = image
        self.latestFrameLock.unlock()
    }
}

final nonisolated class PhotoCaptureDelegateBridge: NSObject, AVCapturePhotoCaptureDelegate {
    private let stateLock = NSLock()
    private var continuation: CheckedContinuation<UIImage?, Never>?
    private var hasCompleted = false

    init(continuation: CheckedContinuation<UIImage?, Never>) {
        self.continuation = continuation
        super.init()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil else {
            self.complete(with: nil)
            return
        }

        self.complete(with: photo.fileDataRepresentation())
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if error != nil {
            self.complete(with: nil)
        }
    }

    func cancel() {
        self.complete(with: nil)
    }

    private func complete(with photoData: Data?) {
        self.stateLock.lock()
        let shouldComplete = !self.hasCompleted
        self.hasCompleted = true
        let continuation = self.continuation
        self.continuation = nil
        self.stateLock.unlock()

        guard shouldComplete else { return }

        let image = photoData.flatMap { UIImage(data: $0) }
        continuation?.resume(returning: image)
    }
}
