//
//  FoodScannerView.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import SwiftUI

struct FoodScannerView: View {
    @State private var cameraLifecycle = CameraLifecycle.setup
    @State private var viewModel: FoodScannerViewModel

    init(viewModel: FoodScannerViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            NutrisDesign.Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: Layout.contentSpacing) {
                self.cameraSection

                self.content

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Scan Food")
        .task(id: self.cameraLifecycle) {
            switch self.cameraLifecycle {
            case .setup:
                await self.viewModel.setupCamera()

            case .teardown:
                await self.viewModel.handleDisappear()
            }
        }
        .onAppear {
            self.cameraLifecycle = .setup
        }
        .onDisappear {
            self.cameraLifecycle = .teardown
        }
    }
}

// MARK: - State Rendering

private extension FoodScannerView {
    enum CameraLifecycle: Hashable {
        case setup
        case teardown
    }

    enum Layout {
        static let contentSpacing: CGFloat = 20
        static let permissionSpacing: CGFloat = 12
        static let cameraCornerRadius: CGFloat = 20
        static let previewHeight: CGFloat = 320
    }

    @ViewBuilder
    var cameraSection: some View {
        if self.viewModel.hasCameraPermission {
            if let session = self.viewModel.cameraSession {
                CameraPreviewView(session: session)
                    .frame(height: Layout.previewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Layout.cameraCornerRadius))
            } else {
                CameraPreviewPlaceholder()
            }
        } else {
            self.permissionView
        }
    }

    @ViewBuilder
    var content: some View {
        switch self.viewModel.state {
        case .idle:
            Button("Capture") {
                self.viewModel.captureAndScan()
            }
            .buttonStyle(.borderedProminent)
            .tint(NutrisDesign.Color.primary)
            .disabled(!self.viewModel.isCameraReady)

        case .processing:
            ProgressView("Analyzing...")
                .tint(NutrisDesign.Color.primary)

        case let .success(result):
            VStack(spacing: Layout.permissionSpacing) {
                RecognitionResultCard(
                    title: "Recognition Result",
                    resultText: result.recognizedFoodName
                )

                Button("Scan Again") {
                    self.viewModel.reset()
                }
                .buttonStyle(.bordered)
            }

        case let .error(error):
            VStack(spacing: Layout.permissionSpacing) {
                Text(self.message(for: error))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.red)

                if self.viewModel.hasCameraPermission {
                    Button("Try Again") {
                        self.viewModel.reset()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Retry Camera Access") {
                        Task {
                            await self.viewModel.setupCamera()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    var permissionView: some View {
        VStack(spacing: Layout.permissionSpacing) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)

            Text("Camera access is required to scan food.")
                .multilineTextAlignment(.center)

            if self.viewModel.isPermissionDenied, let settingsURL = self.viewModel.appSettingsURL {
                Link("Open Settings", destination: settingsURL)
                    .buttonStyle(.borderedProminent)
                    .tint(NutrisDesign.Color.primary)
            }

            Button("Retry Permission") {
                Task {
                    await self.viewModel.setupCamera()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(height: Layout.previewHeight)
    }

    func message(for error: FoodScannerError) -> String {
        switch error {
        case .permissionDenied:
            "Camera access was denied. Allow access in Settings to continue."

        case .permissionRestricted:
            "Camera access is restricted on this device."

        case .cameraConfigurationFailed:
            "Unable to start the camera. Please try again."

        case .noFrameAvailable:
            "No frame available yet. Hold steady and try again."

        case .recognitionFailed:
            "We couldn't recognize this item. Try again with better lighting."

        case .unknown:
            "An unexpected error occurred. Please try again."
        }
    }
}

#Preview {
    FoodScannerView(viewModel: AppDependencies.preview.makeFoodScannerViewModel())
}
