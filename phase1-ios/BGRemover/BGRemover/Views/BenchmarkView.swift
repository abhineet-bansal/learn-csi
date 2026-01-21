//
//  BenchmarkView.swift
//  BGRemover
//
//  Automated benchmark mode UI
//

import SwiftUI

struct BenchmarkView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var benchmarkRunner = BenchmarkRunner()

    @State private var selectedApproaches: Set<String> = Set(["Vision API", "Core ML Zoo", "HuggingFace"])
    @State private var iterations = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Automated Benchmark")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Run systematic performance tests across all approaches")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

                Divider()

                // Run Benchmark Button
                Button(action: runBenchmark) {
                    HStack {
                        if benchmarkRunner.isRunning {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }
                        Text(benchmarkRunner.isRunning ? "Running..." : "Run Benchmark Suite")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(benchmarkRunner.isRunning || selectedApproaches.isEmpty)
                .padding(.horizontal)

                // Progress Section
                if benchmarkRunner.isRunning {
                    VStack(alignment: .leading, spacing: 12) {
                        ProgressView(value: benchmarkRunner.progress) {
                            Text("Progress")
                                .font(.subheadline)
                        }

                        Text(benchmarkRunner.currentStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Results Section
                if !benchmarkRunner.results.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Results (\(benchmarkRunner.results.count))")
                                .font(.headline)
                        }

                        // Summary Table
                        ForEach(groupedResults(), id: \.0) { approach, results in
                            BenchmarkResultCard(approach: approach, results: results)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private func runBenchmark() {
        // Load all test images from assets (img01 - img30 with corresponding masks)
        var testImages: [(name: String, image: UIImage, groundTruth: UIImage?)] = []

        for i in 1...30 {
            let imageName = String(format: "img%02d", i)
            let maskName = String(format: "mask%02d", i)

            if let image = UIImage(named: imageName),
               let mask = UIImage(named: maskName) {
                testImages.append((imageName, image, mask))
            } else {
                print("⚠️ Warning: Could not load \(imageName) or \(maskName)")
            }
        }

        guard !testImages.isEmpty else {
            print("❌ Error: No test images loaded")
            return
        }

        let selectedApproachObjects = appState.availableApproaches.filter { selectedApproaches.contains($0.name) }

        let config = BenchmarkConfig(
            iterations: iterations
        )

        let runner = BenchmarkRunner(config: config)
        // Note: We need to use the existing benchmarkRunner for state updates
        Task {
            await benchmarkRunner.runBenchmarks(approaches: selectedApproachObjects, testImages: testImages)
        }
    }

    private func groupedResults() -> [(String, [BenchmarkResult])] {
        let grouped = Dictionary(grouping: benchmarkRunner.results, by: { $0.approachName })
        return grouped.sorted(by: { $0.key < $1.key })
    }
}

// MARK: - Supporting Views

struct BenchmarkResultCard: View {
    let approach: String
    let results: [BenchmarkResult]

    private var avgInference: Double {
        results.map { $0.metrics.inferenceTimeMs }.reduce(0, +) / Double(results.count)
    }

    private var avgMemory: Double {
        results.map { $0.metrics.memoryUsageMB }.reduce(0, +) / Double(results.count)
    }

    private var avgPixelAccuracy: Double {
        results.compactMap { $0.qualityMetrics?.pixelAccuracy }.reduce(0, +) / Double(max(results.count, 1))
    }

    private var avgF1: Double {
        results.compactMap { $0.qualityMetrics?.f1Score }.reduce(0, +) / Double(max(results.count, 1))
    }

    private var avgIoU: Double {
        results.compactMap { $0.qualityMetrics?.iou }.reduce(0, +) / Double(max(results.count, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(approach)
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                // Performance metrics
                HStack {
                    MetricCell(title: "Avg Inference", value: String(format: "%.2f ms", avgInference))
                    Spacer()
                    MetricCell(title: "Avg Memory", value: String(format: "%.2f MB", avgMemory))
                    Spacer()
                    MetricCell(title: "Images", value: "\(results.count)")
                }

                // Quality metrics
                HStack {
                    MetricCell(title: "Avg IoU", value: String(format: "%.4f", avgIoU))
                    Spacer()
                    MetricCell(title: "Avg Pixel Accuracy", value: String(format: "%.4f", avgPixelAccuracy))
                    Spacer()
                    MetricCell(title: "Avg F1 Score", value: String(format: "%.4f", avgF1))
                }
            }
            .padding(.vertical, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MetricCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    BenchmarkView()
        .environmentObject(AppState())
}
