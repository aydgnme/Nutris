//
//  CameraPermissionManager.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import AVFoundation
import UIKit

protocol CameraPermissionManaging: Sendable {
    func requestPermission() async -> Bool
    func currentAuthorizationStatus() -> AVAuthorizationStatus
    var appSettingsURL: URL? { get }
}

struct CameraPermissionManager: CameraPermissionManaging {
    var appSettingsURL: URL? {
        URL(string: UIApplication.openSettingsURLString)
    }

    func requestPermission() async -> Bool {
        switch self.currentAuthorizationStatus() {
        case .authorized:
            true

        case .notDetermined:
            await AVCaptureDevice.requestAccess(for: .video)

        default:
            false
        }
    }

    func currentAuthorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }
}
