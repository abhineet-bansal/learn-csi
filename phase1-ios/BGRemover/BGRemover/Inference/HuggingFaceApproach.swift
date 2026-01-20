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
