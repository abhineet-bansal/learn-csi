//
//  HuggingFaceApproach.swift
//  BGRemover
//
//  Approach #3 for background removal: Using an open source model from hugging face
//

import UIKit
import CoreML

class HuggingFaceApproach: BGRemovalApproach {
    let name = "HuggingFace"
    private(set) var isModelLoaded = false
    private var briaRmbgModel: BriaRMBG1_4?
    var modelSizeInfo: ModelSizeInfo? = nil

    func initialize() async throws {
        briaRmbgModel = try BriaRMBG1_4(configuration: MLModelConfiguration())
        isModelLoaded = true
    }

    func removeBackground(from image: UIImage) async throws -> BGRemovalResult {
        guard isModelLoaded, let model = briaRmbgModel else {
            throw BGRemovalError.modelNotLoaded
        }
        
        // Preprocess input image
        guard let modelInput = preprocess(image: image) else {
            throw BGRemovalError.invalidImage
        }

        // Track memory before inference
        let memoryBefore = ImageProcessingHelpers.getMemoryUsage()

        // Run inference with timing (async on background queue)
        let startTime = Date()
        let result = try await Task.detached(priority: .userInitiated) {
            guard let prediction = try? await model.prediction(input: modelInput) else {
                throw BGRemovalError.processingFailed("CoreML prediction failed")
            }
            return prediction
        }.value
        let inferenceTime = Date().timeIntervalSince(startTime)
        
        // Postprocess model prediction
        guard let mask = postprocess(original: image, prediction: result) else {
            throw BGRemovalError.processingFailed("Failed to create mask from segmentation")
        }

        // Apply mask to input image
        guard let processedImage = ImageProcessingHelpers.applyMask(mask, to: image) else {
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

    func cleanup() {
        isModelLoaded = false
    }
    
    private func preprocess(image: UIImage) -> BriaRMBG1_4Input? {
        // RMBG 1.4 expects input images to be of 1024x1024 size
        let targetSize = CGSize(width: 1024, height: 1024)
        
        let scale = image.scale
        let pixelWidth = Int(targetSize.width * scale)
        let pixelHeight = Int(targetSize.height * scale)
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

        context.interpolationQuality = .high
        context.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        guard let resizedCGImage = context.makeImage() else {
            return nil
        }
        
        var modelInput = try? BriaRMBG1_4Input(inputWith: resizedCGImage)
        return modelInput
    }
    
    // Convert 1024x1024 grayscale image (kCVPixelFormatType_OneComponent8) to original image size
    private func postprocess(original: UIImage, prediction: BriaRMBG1_4Output) -> UIImage? {
        let pixelBuffer = prediction.output
        
        // Create CGImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        // Resize CGImage to original image size
        let scale = original.scale
        let pixelWidth = Int(original.size.width * scale)
        let pixelHeight = Int(original.size.height * scale)
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

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        guard let resizedCGImage = context.makeImage() else {
            return nil
        }

        return UIImage(cgImage: resizedCGImage, scale: scale, orientation: original.imageOrientation)
    }
}
