//
//  CoreMLApproach.swift
//  BGRemover
//  Approach #2 for background removal: Using DeepLabV3 from Core ML Model Zoo
//
//  Created by Abhineet Bansal on 27/1/2026.
//

import UIKit
import CoreML

class CoreMLApproach: BGRemovalApproach {
    let name = "Core ML"
    private(set) var isModelLoaded = false
    private var deepLabV3Model: DeepLabV3?

    func initialize() async throws {
        deepLabV3Model = try DeepLabV3(configuration: MLModelConfiguration())
        isModelLoaded = true
    }

    func removeBackground(from image: UIImage) async throws -> BGRemovalResult {
        guard isModelLoaded, let model = deepLabV3Model else {
            throw BGRemovalError.modelNotLoaded
        }
        
        // Fix for an issue when working with non-0 orientation images - the mask and the image need to be orientated similarly
        // Normalize image to orientation 0 before processing
        // This "bakes in" the rotation so we don't need orientation metadata
        guard let normalizedImage = normalizeImageOrientation(image) else {
            throw BGRemovalError.processingFailed("Failed to normalize image orientation")
        }
        
        // Preprocess input image
        guard let modelInput = try? preprocess(image: normalizedImage) else {
            throw BGRemovalError.invalidImage
        }

        // Track memory before inference
        let memoryBefore = MetricsHelper.getMemoryUsage()

        // Run inference with timing (async on background queue)
        let startTime = Date()
        let result = try await Task.detached(priority: .userInitiated) {
            guard let prediction = try? await model.prediction(input: modelInput) else {
                throw BGRemovalError.processingFailed("CoreML prediction failed")
            }
            return prediction
        }.value
        
        let inferenceTime = Date().timeIntervalSince(startTime)

        // Post process model prediction
        guard let mask = postprocess(original: normalizedImage, prediction: result) else {
            throw BGRemovalError.processingFailed("Failed to create mask from segmentation")
        }
        
        // Apply mask to original image
        guard let processedImage = ImageProcessingHelper.applyMask(mask, to: normalizedImage) else {
            throw BGRemovalError.processingFailed("Failed to apply mask")
        }

        // Track peak memory after inference
        let memoryAfter = MetricsHelper.getMemoryUsage()
        let peakMemoryUsage = memoryAfter > memoryBefore ? memoryAfter - memoryBefore : 0

        let metrics = InferenceMetrics(
            inferenceTime: inferenceTime,
            peakMemoryUsage: peakMemoryUsage
        )
        return BGRemovalResult(processedImage: processedImage, mask: mask, metrics: metrics)
    }

    func cleanup() {
        deepLabV3Model = nil
        isModelLoaded = false
    }
    
    
    // MARK: - Private Helpers
    
    private func preprocess(image: UIImage) throws -> DeepLabV3Input? {
        // Convert input image to pixel buffer
        guard let cvPixelBuffer = ImageProcessingHelper.uiImageToPixelBuffer(image, width: 513, height: 513) else {
            throw BGRemovalError.invalidImage
        }

        return DeepLabV3Input(image: cvPixelBuffer)
    }
    
    private func postprocess(original: UIImage, prediction: DeepLabV3Output) -> UIImage? {
        let segmentation = prediction.semanticPredictions
        
        // Convert MLMultiArray segmentation to binary mask of size 513x513
        let width = segmentation.shape[1].intValue  // 513
        let height = segmentation.shape[0].intValue // 513

        // Create grayscale pixel data (0 = background, 255 = foreground)
        var maskPixels = [UInt8](repeating: 0, count: width * height)

        // Iterate through segmentation array
        // Class 0 = background, any other class = foreground (person, objects, etc.)
        for row in 0..<height {
            for col in 0..<width {
                let index = row * width + col
                
                // Segmentation array has shape [513, 513], and strides [513, 1], so it is a row-first organisation of a 2d array into a 1d array
                let classValue = segmentation[index].intValue

                // Binary mask: 0 for background (class 0), 255 for any foreground class
                maskPixels[index] = classValue == 0 ? 0 : 255
            }
        }
        
        // Create CGImage from grayscale pixel data, of size 513x513
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
        ), let smallMask = context.makeImage() else {
            return nil
        }
        
        // Target mask size should be same as the original input image
        let scale = original.scale
        let targetSize = original.size
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }

        // Draw the small image scaled to fill the target size
        context.translateBy(x: 0, y: targetSize.height)
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .high
        context.draw(smallMask, in: CGRect(origin: .zero, size: targetSize))

        let mask = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return mask
    }
    
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
}
