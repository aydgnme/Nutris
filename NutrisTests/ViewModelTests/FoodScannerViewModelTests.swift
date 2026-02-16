//
//  FoodScannerViewModelTests.swift
//  NutrisTests
//
//  Created by Mert Aydogan on 16.02.2026.
//

@testable import Nutris
import UIKit
import XCTest

final class TestFoodRecognitionService: FoodRecognitionService {
    var result: Result<String, Error>

    init(result: Result<String, Error>) {
        self.result = result
    }

    func recognizeFood(from image: UIImage) async throws -> String {
        try self.result.get()
    }
}

@MainActor
final class FoodScannerViewModelTests: XCTestCase {
    func test_startScanning_success() async throws {
        let mockService = TestFoodRecognitionService(
            result: .success("Avocado Toast")
        )

        let viewModel = FoodScannerViewModel(
            recognitionService: mockService
        )

        XCTAssertEqual(viewModel.state, .idle)

        viewModel.startScanning(with: UIImage())

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(viewModel.state, .success("Avocado Toast"))
    }

    func test_startScanning_failure() async throws {
        struct TestError: Error {}

        let mockService = TestFoodRecognitionService(
            result: .failure(TestError())
        )

        let viewModel = FoodScannerViewModel(
            recognitionService: mockService
        )

        viewModel.startScanning(with: UIImage())

        try await Task.sleep(for: .milliseconds(50))

        if case .error = viewModel.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected error state")
        }
    }
}
