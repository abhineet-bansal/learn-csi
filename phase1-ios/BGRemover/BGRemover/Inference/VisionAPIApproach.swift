//
//  VisionAPIApproach.swift
//  BGRemover
//
//  Approach #1 for background removal: Using Apple's Vision API
//

import UIKit
import Vision

class VisionAPIApproach: BGRemovalApproach {
    let name = "Vision API"
    private(set) var isModelLoaded = false
    private var maskRequest: GenerateForegroundInstanceMaskRequest?
    var modelSizeInfo: ModelSizeInfo? = nil

    func initialize() async throws {
        maskRequest = GenerateForegroundInstanceMaskRequest()
        isModelLoaded = true
    }

    func removeBackground(from image: UIImage) async throws -> BGRemovalResult {
        guard isModelLoaded, let request = maskRequest else {
            throw BGRemovalError.modelNotLoaded
        }
        
        guard let cgImage = image.cgImage else {
            throw BGRemovalError.invalidImage
        }
        
        let startTime = Date()
        let handler = ImageRequestHandler(cgImage)
        
        guard let result = try await handler.perform(request) else {
            throw BGRemovalError.processingFailed("Vision API returned nil results")
        }

        let maskedImageBuffer = try result.generateScaledMask(for: result.allInstances, scaledToImageFrom: handler)
        guard let maskedImage = ImageProcessingHelpers.pixelBufferToUIImage(maskedImageBuffer, orientation: image.imageOrientation) else {
            throw BGRemovalError.processingFailed("Invalid result, couldn't create mask")
        }
        
        guard let processedImage = ImageProcessingHelpers.applyMask(maskedImage, to: image) else {
            throw BGRemovalError.processingFailed("Invalid result, couldn't apply mask")
        }
        
        let inferenceTime = Date().timeIntervalSince(startTime)
        let memoryUsage = ImageProcessingHelpers.getMemoryUsage()

        let metrics = InferenceMetrics(inferenceTime: inferenceTime, peakMemoryUsage: memoryUsage, modelLoadTime: nil, isColdStart: false)
        return BGRemovalResult(processedImage: processedImage, mask: maskedImage, metrics: metrics)
    }

    func cleanup() {
        isModelLoaded = false
    }
}
