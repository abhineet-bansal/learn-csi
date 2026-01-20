//
//  BGRemovalApproach.swift
//  BGRemover
//
//  Protocol defining the interface for all background removal approaches
//

import UIKit
import CoreImage

/// Result of a background removal operation
struct BGRemovalResult {
    let processedImage: UIImage
    let mask: UIImage?
    let metrics: InferenceMetrics
}

/// Metrics collected during inference
struct InferenceMetrics {
    let inferenceTime: TimeInterval             // in seconds
    let peakMemoryUsage: UInt64                 // in bytes
    let modelLoadTime: TimeInterval?            // only for cold start
    let isColdStart: Bool
    
    var inferenceTimeMs: Double {
         inferenceTime * 1000
     }

     var memoryUsageMB: Double {
         Double(peakMemoryUsage) / (1024 * 1024)
     }
}

/// Protocol that all background removal approaches must conform to
protocol BGRemovalApproach {
    var name: String { get }
    var isModelLoaded: Bool { get }
    var modelSizeInfo: ModelSizeInfo? { get }
    func initialize(completion: @escaping (Result<Void, Error>) -> Void)
    func removeBackground(
        from image: UIImage,
        completion: @escaping (Result<BGRemovalResult, Error>) -> Void
    )
    func cleanup()
}

/// Information about model size
struct ModelSizeInfo {
    let modelFileSize: UInt64                   // in bytes
    let compiledModelSize: UInt64?              // in bytes (if applicable)
}

/// Errors that can occur during background removal
enum BGRemovalError: LocalizedError {
    case modelNotLoaded
    case invalidImage
    case processingFailed(String)
    case modelLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model not loaded. Call initialize() first."
        case .invalidImage:
            return "Invalid input image"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .modelLoadFailed(let message):
            return "Model load failed: \(message)"
        }
    }
}
