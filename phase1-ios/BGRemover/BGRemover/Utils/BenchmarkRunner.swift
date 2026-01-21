//
//  BenchmarkRunner.swift
//  BGRemover
//
//  Infrastructure for running benchmark tests
//

import UIKit
import Foundation
internal import Combine

/// Single benchmark result for one image + approach combination
struct BenchmarkResult {
    let approachName: String
    let imageName: String
    let imageSize: CGSize
    let metrics: InferenceMetrics
    let timestamp: Date

    // Quality metrics (optional, if ground truth is available)
    var qualityMetrics: QualityMetrics?
}

/// Quality metrics (for images with ground truth masks)
struct QualityMetrics {
    let iou: Double                         // Intersection over Union
    let pixelAccuracy: Double
    let f1Score: Double
}

/// Configuration for benchmark runs
struct BenchmarkConfig {
    let iterations: Int                     // Number of times to run each image (default: 3, report median)

    static let `default` = BenchmarkConfig(
        iterations: 3
    )
}

/// Runs automated benchmarks across approaches and test images
@MainActor
class BenchmarkRunner: ObservableObject {
    @Published var isRunning = false
    @Published var progress: Double = 0.0
    @Published var currentStatus = ""
    @Published var results: [BenchmarkResult] = []

    private let config: BenchmarkConfig

    init(config: BenchmarkConfig = .default) {
        self.config = config
    }

    /// Run benchmarks for all approaches on all test images
    func runBenchmarks(
        approaches: [BGRemovalApproach],
        testImages: [(name: String, image: UIImage, groundTruth: UIImage?)]
    ) async {
        isRunning = true
        results = []
        progress = 0.0

        let totalRuns = approaches.count * testImages.count * config.iterations
        var completedRuns = 0

        // Iterate through each approach
        for approach in approaches {
            currentStatus = "Initializing \(approach.name)..."
            print(currentStatus)

            // Initialize the approach (cold start)
            do {
                try await approach.initialize()
            } catch {
                print("❌ Error initializing \(approach.name): \(error)")
                continue
            }

            // Test each image
            for testImage in testImages {
                // Run multiple iterations and collect results
                var iterationResults: [BenchmarkResult] = []

                for iteration in 1...config.iterations {
                    currentStatus = "Testing \(approach.name) on \(testImage.name) (iteration \(iteration)/\(config.iterations))..."
                    print(currentStatus)

                    do {
                        let removalResult = try await approach.removeBackground(from: testImage.image)

                        var benchmarkResult = BenchmarkResult(
                            approachName: approach.name,
                            imageName: testImage.name,
                            imageSize: testImage.image.size,
                            metrics: removalResult.metrics,
                            timestamp: Date()
                        )

                        // Calculate quality metrics if ground truth is available
                        if let groundTruth = testImage.groundTruth, let mask = removalResult.mask {
                            benchmarkResult.qualityMetrics = ImageProcessingHelpers.calculateQualityMetrics(groundTruth: groundTruth, predicted: mask)
                        }

                        iterationResults.append(benchmarkResult)
                    } catch {
                        print("❌ Error processing \(testImage.name) with \(approach.name): \(error)")
                    }

                    completedRuns += 1
                    progress = Double(completedRuns) / Double(totalRuns)
                }

                // Use median result (iteration 2 out of 3)
                if let medianResult = iterationResults.sorted(by: { $0.metrics.inferenceTime < $1.metrics.inferenceTime })[safe: config.iterations / 2] {
                    results.append(medianResult)
                }
            }

            // Cleanup after each approach
            approach.cleanup()
        }

        currentStatus = "Benchmark complete! Processed \(completedRuns) runs."
        print(currentStatus)
        isRunning = false

        printSummary()
    }

    /// Print summary to console
    func printSummary() {
        print("\n" + String(repeating: "=", count: 80))
        print("BENCHMARK SUMMARY")
        print(String(repeating: "=", count: 80))

        let groupedByApproach = Dictionary(grouping: results, by: { $0.approachName })

        for (approach, approachResults) in groupedByApproach.sorted(by: { $0.key < $1.key }) {
            print("\n📱 \(approach)")
            print(String(repeating: "-", count: 80))

            let avgInference = approachResults.map { $0.metrics.inferenceTimeMs }.reduce(0, +) / Double(approachResults.count)
            let avgMemory = approachResults.map { Double($0.metrics.memoryUsageMB) }.reduce(0, +) / Double(approachResults.count)

            print(String(format: "  Avg Inference Time: %.2f ms", avgInference))
            print(String(format: "  Avg Memory Usage: %.2f MB", avgMemory))

            if let coldStart = approachResults.first(where: { $0.metrics.isColdStart }) {
                if let loadTime = coldStart.metrics.modelLoadTime {
                    print(String(format: "  Cold Start Time: %.2f ms", loadTime * 1000))
                }
            }

            // Quality metrics (if ground truth available)
            let resultsWithQuality = approachResults.compactMap { $0.qualityMetrics }
            if !resultsWithQuality.isEmpty {
                let avgIoU = resultsWithQuality.map { $0.iou }.reduce(0, +) / Double(resultsWithQuality.count)
                let avgPixelAccuracy = resultsWithQuality.map { $0.pixelAccuracy }.reduce(0, +) / Double(resultsWithQuality.count)
                let avgF1Score = resultsWithQuality.map { $0.f1Score }.reduce(0, +) / Double(resultsWithQuality.count)

                print(String(format: "  Avg IoU: %.4f", avgIoU))
                print(String(format: "  Avg Pixel Accuracy: %.4f", avgPixelAccuracy))
                print(String(format: "  Avg F1 Score: %.4f", avgF1Score))
            }
        }

        print("\n" + String(repeating: "=", count: 80))
    }
}

// MARK: - Helper Extensions

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
