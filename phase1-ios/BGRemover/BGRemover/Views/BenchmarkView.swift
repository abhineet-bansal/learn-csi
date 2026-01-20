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
                            VStack(alignment: .leading, spacing: 8) {
                                Text(approach)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                let avgInference = results.map { $0.metrics.inferenceTimeMs }.reduce(0, +) / Double(results.count)
                                let avgMemory = results.map { $0.metrics.memoryUsageMB }.reduce(0, +) / Double(results.count)

                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Avg Inference")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.2f ms", avgInference))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }

                                    Spacer()

                                    VStack(alignment: .leading) {
                                        Text("Avg Memory")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.2f MB", avgMemory))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }

                                    Spacer()

                                    VStack(alignment: .leading) {
                                        Text("Images")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("\(results.count)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
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
        // TODO: Load actual test images
        // For now, creating a dummy test image
        let testImages: [(name: String, image: UIImage, groundTruth: UIImage?)] = [
            ("sample", UIImage(systemName: "photo")!, nil)
        ]

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

#Preview {
    BenchmarkView()
        .environmentObject(AppState())
}
