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

    func initialize(completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO: To implement
        isModelLoaded = true
        completion(.success(()))
    }

    func removeBackground(from image: UIImage, completion: @escaping (Result<BGRemovalResult, Error>) -> Void) {
        // TODO: To implement
        let metrics = InferenceMetrics(inferenceTime: 0, peakMemoryUsage: 0, modelLoadTime: nil, isColdStart: false)
        let result = BGRemovalResult(processedImage: image, mask: nil, metrics: metrics)
        completion(.success(result))
    }

    func cleanup() {
        isModelLoaded = false
    }
}
