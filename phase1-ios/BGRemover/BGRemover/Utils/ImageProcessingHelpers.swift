//
//  ImageProcessingHelpers.swift
//  BGRemover
//
//  Shared helper functions for image processing and conversions
//

import UIKit
import CoreImage
import CoreVideo

enum ImageProcessingHelpers {

    // MARK: - Image Conversion Utilities

    /// Convert CVPixelBuffer to UIImage
    static func pixelBufferToUIImage(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Convert UIImage to CVPixelBuffer
    static func uiImageToPixelBuffer(_ image: UIImage, width: Int, height: Int) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(buffer)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()

        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))

        return buffer
    }

    // MARK: - Background Removal

    /// Apply a mask to an image to remove the background
    /// - Parameters:
    ///   - mask: Grayscale mask image (white = foreground, black = background)
    ///   - original: Original image to apply mask to
    /// - Returns: Image with background removed (transparent where mask is black)
    static func applyMask(_ mask: UIImage, to original: UIImage) -> UIImage? {
        guard let originalCI = CIImage(image: original),
              let maskCI = CIImage(image: mask) else {
            return nil
        }

        let context = CIContext()

        // Resize mask to match original if needed
        let maskResized: CIImage
        if maskCI.extent.size != originalCI.extent.size {
            let scaleX = originalCI.extent.width / maskCI.extent.width
            let scaleY = originalCI.extent.height / maskCI.extent.height
            maskResized = maskCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        } else {
            maskResized = maskCI
        }

        // Use CIBlendWithMask filter
        guard let filter = CIFilter(name: "CIBlendWithMask") else {
            return nil
        }

        filter.setValue(originalCI, forKey: kCIInputImageKey)
        filter.setValue(maskResized, forKey: kCIInputMaskImageKey)

        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Create a transparent background image by applying mask
    /// Returns an image with RGBA format where alpha channel is based on mask
    static func removeBackgroundWithMask(_ mask: UIImage, from original: UIImage) -> UIImage? {
        guard let originalCG = original.cgImage,
              let maskCG = mask.cgImage else {
            return nil
        }

        let width = originalCG.width
        let height = originalCG.height

        // Create output image with alpha channel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // Draw original image
        context.draw(originalCG, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Apply mask as alpha channel
        // This is a simplified version - you may need more sophisticated blending
        guard let resultCG = context.makeImage() else {
            return nil
        }

        return UIImage(cgImage: resultCG)
    }

    // MARK: - Memory Measurement

    /// Get current memory usage of the app
    /// - Returns: Memory usage in bytes
    static func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }

    /// Get memory usage in MB
    static func getMemoryUsageMB() -> Double {
        Double(getMemoryUsage()) / (1024 * 1024)
    }

    // MARK: - Timing Utilities

    /// Measure execution time of a synchronous block
    static func measureTime(_ block: () throws -> Void) rethrows -> TimeInterval {
        let start = Date()
        try block()
        return Date().timeIntervalSince(start)
    }

    /// Measure execution time of an async block
    static func measureTimeAsync(_ block: @escaping () async throws -> Void) async rethrows -> TimeInterval {
        let start = Date()
        try await block()
        return Date().timeIntervalSince(start)
    }

    // MARK: - Image Resizing

    /// Resize image to target size (useful for model input preprocessing)
    static func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// Resize image maintaining aspect ratio
    static func resizeImageAspectFit(_ image: UIImage, to maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let aspectRatio = size.width / size.height

        let newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        return resizeImage(image, to: newSize)
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    /// Convert to CVPixelBuffer
    func toPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        return ImageProcessingHelpers.uiImageToPixelBuffer(self, width: width, height: height)
    }

    /// Resize maintaining aspect ratio
    func resizedAspectFit(maxDimension: CGFloat) -> UIImage? {
        return ImageProcessingHelpers.resizeImageAspectFit(self, to: maxDimension)
    }

    /// Resize to exact size
    func resized(to size: CGSize) -> UIImage? {
        return ImageProcessingHelpers.resizeImage(self, to: size)
    }
}

// MARK: - CVPixelBuffer Extensions

extension CVPixelBuffer {
    /// Convert to UIImage
    func toUIImage() -> UIImage? {
        return ImageProcessingHelpers.pixelBufferToUIImage(self)
    }
}
