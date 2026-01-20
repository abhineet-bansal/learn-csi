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
