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
    var modelSizeInfo: ModelSizeInfo? = nil

    func initialize() async throws {
        // TODO: To implement
        isModelLoaded = true
    }

    func removeBackground(from image: UIImage) async throws -> BGRemovalResult {
        // TODO: To implement
        let metrics = InferenceMetrics(inferenceTime: 0, peakMemoryUsage: 0, modelLoadTime: nil, isColdStart: false)
        return BGRemovalResult(processedImage: image, mask: nil, metrics: metrics)
    }

    func cleanup() {
        isModelLoaded = false
    }
}
