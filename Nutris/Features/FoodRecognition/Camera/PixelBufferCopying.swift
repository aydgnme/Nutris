//
//  PixelBufferCopying.swift
//  Nutris
//
//  Created by Mert Aydogan on 16.02.2026.
//

import CoreVideo
import Foundation

nonisolated func copyPixelBuffer(from sourceBuffer: CVPixelBuffer) -> CVPixelBuffer? {
    guard let destinationBuffer = makeDestinationBuffer(from: sourceBuffer) else {
        return nil
    }

    CVBufferPropagateAttachments(sourceBuffer, destinationBuffer)

    CVPixelBufferLockBaseAddress(sourceBuffer, .readOnly)
    CVPixelBufferLockBaseAddress(destinationBuffer, [])

    defer {
        CVPixelBufferUnlockBaseAddress(destinationBuffer, [])
        CVPixelBufferUnlockBaseAddress(sourceBuffer, .readOnly)
    }

    if CVPixelBufferIsPlanar(sourceBuffer) {
        return copyPlanarPixelBuffer(from: sourceBuffer, to: destinationBuffer)
    }

    return copyNonPlanarPixelBuffer(from: sourceBuffer, to: destinationBuffer)
}

private nonisolated func makeDestinationBuffer(from sourceBuffer: CVPixelBuffer) -> CVPixelBuffer? {
    let width = CVPixelBufferGetWidth(sourceBuffer)
    let height = CVPixelBufferGetHeight(sourceBuffer)
    let pixelFormat = CVPixelBufferGetPixelFormatType(sourceBuffer)

    let attributes: CFDictionary = [
        kCVPixelBufferIOSurfacePropertiesKey as String: [:]
    ] as CFDictionary

    var destinationBuffer: CVPixelBuffer?
    let creationStatus = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        pixelFormat,
        attributes,
        &destinationBuffer
    )

    guard creationStatus == kCVReturnSuccess else {
        return nil
    }

    return destinationBuffer
}

private nonisolated func copyPlanarPixelBuffer(
    from sourceBuffer: CVPixelBuffer,
    to destinationBuffer: CVPixelBuffer
) -> CVPixelBuffer? {
    let planeCount = CVPixelBufferGetPlaneCount(sourceBuffer)

    for planeIndex in 0 ..< planeCount {
        guard
            let sourceAddress = CVPixelBufferGetBaseAddressOfPlane(sourceBuffer, planeIndex),
            let destinationAddress = CVPixelBufferGetBaseAddressOfPlane(destinationBuffer, planeIndex)
        else {
            return nil
        }

        let sourceBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(sourceBuffer, planeIndex)
        let destinationBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(destinationBuffer, planeIndex)
        let rows = CVPixelBufferGetHeightOfPlane(sourceBuffer, planeIndex)
        let bytesPerRowToCopy = min(sourceBytesPerRow, destinationBytesPerRow)

        copyRows(
            from: (address: sourceAddress, bytesPerRow: sourceBytesPerRow),
            to: (address: destinationAddress, bytesPerRow: destinationBytesPerRow),
            rows: rows,
            bytesPerRowToCopy: bytesPerRowToCopy
        )
    }

    return destinationBuffer
}

private nonisolated func copyNonPlanarPixelBuffer(
    from sourceBuffer: CVPixelBuffer,
    to destinationBuffer: CVPixelBuffer
) -> CVPixelBuffer? {
    guard
        let sourceAddress = CVPixelBufferGetBaseAddress(sourceBuffer),
        let destinationAddress = CVPixelBufferGetBaseAddress(destinationBuffer)
    else {
        return nil
    }

    let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(sourceBuffer)
    let destinationBytesPerRow = CVPixelBufferGetBytesPerRow(destinationBuffer)
    let rows = CVPixelBufferGetHeight(sourceBuffer)
    let bytesPerRowToCopy = min(sourceBytesPerRow, destinationBytesPerRow)

    copyRows(
        from: (address: sourceAddress, bytesPerRow: sourceBytesPerRow),
        to: (address: destinationAddress, bytesPerRow: destinationBytesPerRow),
        rows: rows,
        bytesPerRowToCopy: bytesPerRowToCopy
    )

    return destinationBuffer
}

private nonisolated func copyRows(
    from source: (address: UnsafeMutableRawPointer, bytesPerRow: Int),
    to destination: (address: UnsafeMutableRawPointer, bytesPerRow: Int),
    rows: Int,
    bytesPerRowToCopy: Int
) {
    for row in 0 ..< rows {
        memcpy(
            destination.address.advanced(by: row * destination.bytesPerRow),
            source.address.advanced(by: row * source.bytesPerRow),
            bytesPerRowToCopy
        )
    }
}
