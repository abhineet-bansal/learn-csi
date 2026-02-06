//
//  MetricsHelper.swift
//  BGRemover
//
//  Created by Abhineet Bansal on 27/1/2026.
//

import UIKit

enum MetricsHelper {
    
    /// Get current memory usage of the app
    /// - Returns: Memory usage in bytes
    static func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
    
    /// Calculate quality metrics by comparing ground truth mask with predicted mask
    static func calculateQualityMetrics(groundTruth: UIImage, predicted: UIImage) -> QualityMetrics? {
        guard let gtCGImage = groundTruth.cgImage,
              let predCGImage = predicted.cgImage else {
            print("⚠️ Warning: Could not get CGImage from ground truth or predicted mask")
            return nil
        }
        
        let width = gtCGImage.width
        let height = gtCGImage.height

        // Ensure images are the same size
        guard width == predCGImage.width && height == predCGImage.height else {
            print("⚠️ Warning: Mask dimensions don't match: GT(\(gtCGImage.width)x\(gtCGImage.height)) vs Pred(\(predCGImage.width)x\(predCGImage.height))")
            return nil
        }

        // Extract pixel data
        guard let gtPixels = ImageProcessingHelper.extractGrayscalePixels(from: gtCGImage),
              let predPixels = ImageProcessingHelper.extractGrayscalePixels(from: predCGImage) else {
            print("⚠️ Warning: Could not extract pixel data")
            return nil
        }

        // Calculate confusion matrix values
        var truePositive = 0   // Predicted foreground, actually foreground
        var trueNegative = 0   // Predicted background, actually background
        var falsePositive = 0  // Predicted foreground, actually background
        var falseNegative = 0  // Predicted background, actually foreground

        let threshold: UInt8 = 128  // Threshold for considering a pixel as foreground

        for i in 0..<(width * height) {
            let gtIsForeground = gtPixels[i] > threshold
            let predIsForeground = predPixels[i] > threshold

            if gtIsForeground && predIsForeground {
                truePositive += 1
            } else if !gtIsForeground && !predIsForeground {
                trueNegative += 1
            } else if predIsForeground && !gtIsForeground {
                falsePositive += 1
            } else if !predIsForeground && gtIsForeground {
                falseNegative += 1
            }
        }

        // Calculate metrics
        let totalPixels = Double(width * height)
        let pixelAccuracy = Double(truePositive + trueNegative) / totalPixels

        let intersection = Double(truePositive)
        let union = Double(truePositive + falsePositive + falseNegative)
        let iou = union > 0 ? intersection / union : 0.0

        let f1Denominator = Double(2 * truePositive + falsePositive + falseNegative)
        let f1Score = f1Denominator > 0 ? (2.0 * Double(truePositive)) / f1Denominator : 0.0

        return QualityMetrics(
            iou: iou,
            pixelAccuracy: pixelAccuracy,
            f1Score: f1Score
        )
    }
}
