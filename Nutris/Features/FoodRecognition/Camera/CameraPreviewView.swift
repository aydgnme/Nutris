//
//  CameraPreviewView.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewContainerView {
        let view = CameraPreviewContainerView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = self.session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewContainerView, context: Context) {
        if uiView.previewLayer.session !== self.session {
            uiView.previewLayer.session = self.session
        }
    }
}

final class CameraPreviewContainerView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(self.previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.previewLayer.frame = bounds
    }
}
