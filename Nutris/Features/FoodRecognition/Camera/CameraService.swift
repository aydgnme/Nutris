//
//  CameraService.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

@preconcurrency import AVFoundation
import CoreVideo
import Foundation

nonisolated enum CameraServiceError: Error {
    case configurationFailed
}

nonisolated enum CameraSessionState: Sendable, Equatable {
    case stopped
    case running
    case interrupted
}

nonisolated protocol CameraServicing: Sendable {
    var previewSession: AVCaptureSession { get async }
    var sessionState: CameraSessionState { get async }

    func configure() async throws
    func start() async
    func stop() async
    func latestFramePixelBuffer() async -> CVPixelBuffer?
    func makeSessionStateStream() async -> AsyncStream<CameraSessionState>
}

private nonisolated enum AppNotifications {
    static let didEnterBackground = Notification.Name("UIApplicationDidEnterBackgroundNotification")
    static let willEnterForeground = Notification.Name("UIApplicationWillEnterForegroundNotification")
}

private nonisolated struct UncheckedPixelBuffer: @unchecked Sendable {
    let value: CVPixelBuffer
}

private nonisolated struct UncheckedSession: @unchecked Sendable {
    let value: AVCaptureSession
}

private final nonisolated class LatestFrameStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.nutris.camera.frame.store", qos: .userInitiated)
    private var latestPixelBuffer: CVPixelBuffer?

    func store(_ pixelBuffer: CVPixelBuffer) {
        let uncheckedPixelBuffer = UncheckedPixelBuffer(value: pixelBuffer)

        self.queue.async {
            self.latestPixelBuffer = uncheckedPixelBuffer.value
        }
    }

    func latestPixelBufferValue() async -> CVPixelBuffer? {
        await withCheckedContinuation { continuation in
            self.queue.async {
                continuation.resume(returning: self.latestPixelBuffer)
            }
        }
    }
}

private final nonisolated class CameraVideoOutputDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let frameStore: LatestFrameStore

    init(frameStore: LatestFrameStore) {
        self.frameStore = frameStore
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard
            let sourcePixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            let copiedPixelBuffer = copyPixelBuffer(from: sourcePixelBuffer)
        else {
            return
        }

        self.frameStore.store(copiedPixelBuffer)
    }
}

actor CameraService: CameraServicing {
    private let session: AVCaptureSession
    private let notificationCenter: NotificationCenter

    private nonisolated let videoOutputQueue = DispatchQueue(
        label: "com.nutris.camera.video.output",
        qos: .userInitiated
    )

    private nonisolated let frameStore: LatestFrameStore

    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoOutputDelegate: CameraVideoOutputDelegate

    private var isConfigured: Bool
    private var shouldRun = false
    private var isRunning = false
    private var isInBackground = false
    private var isSessionInterrupted = false

    private var currentSessionState: CameraSessionState = .stopped
    private var sessionStateContinuations: [UUID: AsyncStream<CameraSessionState>.Continuation] = [:]

    init(
        notificationCenter: NotificationCenter = .default,
        initiallyConfigured: Bool = false
    ) {
        let frameStore = LatestFrameStore()
        let session = AVCaptureSession()

        self.session = session
        self.notificationCenter = notificationCenter
        self.frameStore = frameStore
        self.videoOutputDelegate = CameraVideoOutputDelegate(frameStore: frameStore)
        self.isConfigured = initiallyConfigured

        self.notificationCenter.addObserver(
            self,
            selector: #selector(self.handleDidEnterBackgroundNotification(_:)),
            name: AppNotifications.didEnterBackground,
            object: nil
        )

        self.notificationCenter.addObserver(
            self,
            selector: #selector(self.handleWillEnterForegroundNotification(_:)),
            name: AppNotifications.willEnterForeground,
            object: nil
        )

        self.notificationCenter.addObserver(
            self,
            selector: #selector(self.handleSessionWasInterruptedNotification(_:)),
            name: AVCaptureSession.wasInterruptedNotification,
            object: session
        )

        self.notificationCenter.addObserver(
            self,
            selector: #selector(self.handleSessionInterruptionEndedNotification(_:)),
            name: AVCaptureSession.interruptionEndedNotification,
            object: session
        )
    }

    deinit {
        self.notificationCenter.removeObserver(self)
    }

    var previewSession: AVCaptureSession {
        self.session
    }

    var sessionState: CameraSessionState {
        self.currentSessionState
    }

    func configure() async throws {
        guard !self.isConfigured else {
            return
        }

        self.session.beginConfiguration()
        self.session.sessionPreset = .high

        defer {
            self.session.commitConfiguration()
        }

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
        self.videoOutput.setSampleBufferDelegate(
            self.videoOutputDelegate,
            queue: self.videoOutputQueue
        )

        self.session.addInput(input)
        self.session.addOutput(self.videoOutput)
        self.isConfigured = true
    }

    func start() async {
        self.shouldRun = true
        await self.startIfPossible()
    }

    func stop() async {
        self.shouldRun = false
        await self.stopIfNeeded()
    }

    nonisolated func latestFramePixelBuffer() async -> CVPixelBuffer? {
        await self.frameStore.latestPixelBufferValue()
    }

    func makeSessionStateStream() async -> AsyncStream<CameraSessionState> {
        AsyncStream { continuation in
            let streamID = UUID()
            self.sessionStateContinuations[streamID] = continuation
            continuation.yield(self.currentSessionState)

            continuation.onTermination = { [weak self] _ in
                guard let self else {
                    return
                }

                Task {
                    await self.removeSessionStateContinuation(for: streamID)
                }
            }
        }
    }

    @objc private nonisolated func handleDidEnterBackgroundNotification(_ notification: Notification) {
        Task {
            await self.handleDidEnterBackground()
        }
    }

    @objc private nonisolated func handleWillEnterForegroundNotification(_ notification: Notification) {
        Task {
            await self.handleWillEnterForeground()
        }
    }

    @objc private nonisolated func handleSessionWasInterruptedNotification(_ notification: Notification) {
        Task {
            await self.handleSessionWasInterrupted()
        }
    }

    @objc private nonisolated func handleSessionInterruptionEndedNotification(
        _ notification: Notification
    ) {
        Task {
            await self.handleSessionInterruptionEnded()
        }
    }
}

private extension CameraService {
    func startIfPossible() async {
        guard
            self.shouldRun,
            self.isConfigured,
            !self.isInBackground,
            !self.isSessionInterrupted
        else {
            self.publishSessionState(self.isSessionInterrupted ? .interrupted : .stopped)
            return
        }

        guard !self.isRunning else {
            self.publishSessionState(.running)
            return
        }

        let uncheckedSession = UncheckedSession(value: self.session)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                uncheckedSession.value.startRunning()
                continuation.resume()
            }
        }

        self.isRunning = uncheckedSession.value.isRunning
        self.publishSessionState(self.isRunning ? .running : .stopped)
    }

    func stopIfNeeded() async {
        guard self.isRunning else {
            self.publishSessionState(.stopped)
            return
        }

        let uncheckedSession = UncheckedSession(value: self.session)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                uncheckedSession.value.stopRunning()
                continuation.resume()
            }
        }

        self.isRunning = false
        self.publishSessionState(.stopped)
    }

    func publishSessionState(_ state: CameraSessionState) {
        guard self.currentSessionState != state else {
            return
        }

        self.currentSessionState = state

        for continuation in self.sessionStateContinuations.values {
            continuation.yield(state)
        }
    }

    func removeSessionStateContinuation(for streamID: UUID) {
        self.sessionStateContinuations.removeValue(forKey: streamID)
    }

    func handleDidEnterBackground() async {
        self.isInBackground = true
        await self.stopIfNeeded()
    }

    func handleWillEnterForeground() async {
        self.isInBackground = false
        await self.startIfPossible()
    }

    func handleSessionWasInterrupted() async {
        self.isSessionInterrupted = true
        self.isRunning = false
        self.publishSessionState(.interrupted)
    }

    func handleSessionInterruptionEnded() async {
        self.isSessionInterrupted = false
        await self.startIfPossible()
    }
}
