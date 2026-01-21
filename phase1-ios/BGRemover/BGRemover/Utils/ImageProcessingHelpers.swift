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
    // MARK: - Ground Truth and Result Comparison
    
    /// Calculate quality metrics by comparing ground truth mask with predicted mask
    static func calculateQualityMetrics(groundTruth: UIImage, predicted: UIImage) -> QualityMetrics? {
        guard let gtCGImage = groundTruth.cgImage,
              let predCGImage = predicted.cgImage else {
            print("⚠️ Warning: Could not get CGImage from ground truth or predicted mask")
            return nil
        }
        
        let width = gtCGImage.width
        let height = gtCGImage.height

        // Ensure images are the same size
        guard width == predCGImage.width && height == predCGImage.height else {
            print("⚠️ Warning: Mask dimensions don't match: GT(\(gtCGImage.width)x\(gtCGImage.height)) vs Pred(\(predCGImage.width)x\(predCGImage.height))")
            return nil
        }

        // Extract pixel data
        guard let gtPixels = extractGrayscalePixels(from: gtCGImage),
              let predPixels = extractGrayscalePixels(from: predCGImage) else {
            print("⚠️ Warning: Could not extract pixel data")
            return nil
        }

        // Calculate confusion matrix values
        var truePositive = 0   // Predicted foreground, actually foreground
        var trueNegative = 0   // Predicted background, actually background
        var falsePositive = 0  // Predicted foreground, actually background
        var falseNegative = 0  // Predicted background, actually foreground

        let threshold: UInt8 = 128  // Threshold for considering a pixel as foreground

        for i in 0..<(width * height) {
            let gtIsForeground = gtPixels[i] > threshold
            let predIsForeground = predPixels[i] > threshold

            if gtIsForeground && predIsForeground {
                truePositive += 1
            } else if !gtIsForeground && !predIsForeground {
                trueNegative += 1
            } else if predIsForeground && !gtIsForeground {
                falsePositive += 1
            } else if !predIsForeground && gtIsForeground {
                falseNegative += 1
            }
        }

        // Calculate metrics
        let totalPixels = Double(width * height)
        let pixelAccuracy = Double(truePositive + trueNegative) / totalPixels

        let intersection = Double(truePositive)
        let union = Double(truePositive + falsePositive + falseNegative)
        let iou = union > 0 ? intersection / union : 0.0

        let f1Denominator = Double(2 * truePositive + falsePositive + falseNegative)
        let f1Score = f1Denominator > 0 ? (2.0 * Double(truePositive)) / f1Denominator : 0.0

        return QualityMetrics(
            iou: iou,
            pixelAccuracy: pixelAccuracy,
            f1Score: f1Score
        )
    }


    // MARK: - Image Conversion Utilities

    /// Convert CVPixelBuffer to UIImage
    static func pixelBufferToUIImage(_ pixelBuffer: CVPixelBuffer, orientation: UIImage.Orientation = .up) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
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
    
    /// Extract grayscale pixel values from CGImage
    static func extractGrayscalePixels(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 1
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelData
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

        return UIImage(cgImage: cgImage, scale: original.scale, orientation: original.imageOrientation)
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
    /// - Parameters:
    ///   - image: Source image to resize
    ///   - targetSize: Target size in points
    /// - Returns: Resized image with the same scale as the input image
    static func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        // Calculate pixel dimensions based on target size and image scale
        let scale = image.scale
        let pixelWidth = Int(targetSize.width * scale)
        let pixelHeight = Int(targetSize.height * scale)

        // Use CGContext for precise control over pixel dimensions
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: pixelWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // Draw the image scaled to fit the context
        context.interpolationQuality = .high
        context.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        guard let resizedCGImage = context.makeImage() else {
            return nil
        }

        // Create UIImage with the same scale as input
        return UIImage(cgImage: resizedCGImage, scale: scale, orientation: image.imageOrientation)
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
