//
//  CameraServiceTests.swift
//  NutrisTests
//
//  Created by Mert Aydogan on 16.02.2026.
//

import AVFoundation
@testable import Nutris
import XCTest

final class CameraServiceTests: XCTestCase {
    func test_sessionInterruption_setsInterruptedState() async {
        let notificationCenter = NotificationCenter()
        let service = CameraService(
            notificationCenter: notificationCenter,
            initiallyConfigured: false
        )
        let session = await service.previewSession

        notificationCenter.post(
            name: AVCaptureSession.wasInterruptedNotification,
            object: session
        )

        await Task.yield()

        await XCTAssertEqual(service.sessionState, .interrupted)
    }

    func test_backgroundToForeground_keepsStoppedWhenNotConfigured() async {
        let notificationCenter = NotificationCenter()
        let service = CameraService(
            notificationCenter: notificationCenter,
            initiallyConfigured: false
        )

        await service.start()

        notificationCenter.post(
            name: Notification.Name("UIApplicationDidEnterBackgroundNotification"),
            object: nil
        )

        await Task.yield()

        await XCTAssertEqual(service.sessionState, .stopped)

        notificationCenter.post(
            name: Notification.Name("UIApplicationWillEnterForegroundNotification"),
            object: nil
        )

        await Task.yield()

        await XCTAssertEqual(service.sessionState, .stopped)
    }
}
