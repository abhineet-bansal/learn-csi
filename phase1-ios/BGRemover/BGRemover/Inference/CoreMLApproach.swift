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
