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
