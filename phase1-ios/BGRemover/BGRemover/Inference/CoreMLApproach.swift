//
//  CoreMLApproach.swift
//  BGRemover
//
//  Approach #2 for background removal: Using a Core ML model from the model zoo
//

import UIKit
import CoreML

class CoreMLApproach: BGRemovalApproach {
    let name = "Core ML Zoo"
    private(set) var isModelLoaded = false
    private var deepLabV3Model: DeepLabV3?
    var modelSizeInfo: ModelSizeInfo? = nil

    func initialize() async throws {
        deepLabV3Model = try DeepLabV3(configuration: MLModelConfiguration())
        isModelLoaded = true
    }

    func removeBackground(from image: UIImage) async throws -> BGRemovalResult {
        guard isModelLoaded, let model = deepLabV3Model else {
            throw BGRemovalError.modelNotLoaded
        }

        // Normalize image to orientation 0 before processing
        // This "bakes in" the rotation so we don't need orientation metadata
        guard let normalizedImage = normalizeImageOrientation(image) else {
            throw BGRemovalError.processingFailed("Failed to normalize image orientation")
        }

        // Track memory before inference
        let memoryBefore = ImageProcessingHelpers.getMemoryUsage()

        // Convert input image to pixel buffer
        guard let cvPixelBuffer = ImageProcessingHelpers.uiImageToPixelBuffer(normalizedImage, width: 513, height: 513) else {
            throw BGRemovalError.invalidImage
        }

        // Run inference with timing (async on background queue)
        let startTime = Date()
        let result = try await Task.detached(priority: .userInitiated) {
            guard let prediction = try? await model.prediction(image: cvPixelBuffer) else {
                throw BGRemovalError.processingFailed("CoreML prediction failed")
            }
            return prediction
        }.value
        let inferenceTime = Date().timeIntervalSince(startTime)

        // Convert MLMultiArray segmentation to binary mask
        guard let mask = convertSegmentationToMask(normalizedImage, result.semanticPredictions) else {
            throw BGRemovalError.processingFailed("Failed to create mask from segmentation")
        }

        // Apply mask to normalized image
        guard let processedImage = ImageProcessingHelpers.applyMask(mask, to: normalizedImage) else {
            throw BGRemovalError.processingFailed("Failed to apply mask")
        }

        // Track peak memory after inference
        let memoryAfter = ImageProcessingHelpers.getMemoryUsage()
        let peakMemoryUsage = memoryAfter > memoryBefore ? memoryAfter - memoryBefore : 0

        let metrics = InferenceMetrics(
            inferenceTime: inferenceTime,
            peakMemoryUsage: peakMemoryUsage,
            modelLoadTime: nil,
            isColdStart: false
        )
        return BGRemovalResult(processedImage: processedImage, mask: mask, metrics: metrics)
    }

    // MARK: - Private Helpers

    /// Normalize image to orientation 0 by redrawing it
    /// - Parameter image: Original image with any orientation
    /// - Returns: New image with orientation 0 and properly rotated pixel data
    private func normalizeImageOrientation(_ image: UIImage) -> UIImage? {
        // If already orientation 0, return as-is
        if image.imageOrientation == .up {
            return image
        }

        // Draw the image in a new context with the orientation applied
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage
    }

    /// Convert DeepLabV3 segmentation output (MLMultiArray with class indices) to binary mask
    /// - Parameter segmentation: MLMultiArray of shape [513, 513] with class indices
    /// - Returns: UIImage representing binary mask (white=foreground, black=background)
    private func convertSegmentationToMask(_ original: UIImage, _ segmentation: MLMultiArray) -> UIImage? {
        let width = segmentation.shape[1].intValue  // 513
        let height = segmentation.shape[0].intValue // 513

        // Create grayscale pixel data (0 = background, 255 = foreground)
        var maskPixels = [UInt8](repeating: 0, count: width * height)

        // Iterate through segmentation array
        // Class 0 = background, any other class = foreground (person, objects, etc.)
        for row in 0..<height {
            for col in 0..<width {
                let index = row * width + col
                let classValue = segmentation[index].intValue

                // Binary mask: 0 for background (class 0), 255 for any foreground class
                maskPixels[index] = classValue == 0 ? 0 : 255
            }
        }

        // Create CGImage from grayscale pixel data
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

        guard let context = CGContext(
            data: &maskPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        guard let cgImage = context.makeImage() else {
            return nil
        }

        let image = UIImage(cgImage: cgImage)

        // Resize mask to match original image dimensions
        return ImageProcessingHelpers.resizeImage(image, to: original.size)
    }

    func cleanup() {
        isModelLoaded = false
    }
}
