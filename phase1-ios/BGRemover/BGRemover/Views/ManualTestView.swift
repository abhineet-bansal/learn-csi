//
//  ManualTestView.swift
//  BGRemover
//
//  Manual testing mode UI for ad-hoc image testing
//

import SwiftUI
import PhotosUI

struct ManualTestView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var maskImage: UIImage?
    @State private var isProcessing = false
    @State private var lastMetrics: InferenceMetrics?
    @State private var showImagePicker = false
    @State private var fullscreenImage: UIImage?
    @State private var fullscreenImageTitle: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Manual Testing")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Test individual images with real-time metrics")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Divider()

                // Approach Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Approach")
                        .font(.headline)
                        .padding(.horizontal)

                    Picker("Approach", selection: Binding(
                        get: { appState.selectedApproach.name },
                        set: { appState.selectApproach(named: $0) }
                    )) {
                        ForEach(appState.availableApproaches, id: \.name) { approach in
                            Text(approach.name).tag(approach.name)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                // Image Selection
                Button(action: { showImagePicker = true }) {
                    Label("Select Image", systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(selectedImage: $selectedImage)
                }

                // Process Button
                if selectedImage != nil {
                    Button(action: processImage) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            }
                            Text(isProcessing ? "Processing..." : "Remove Background")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)
                    .padding(.horizontal)
                }

                // Image Display Section
                if selectedImage != nil || processedImage != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Results")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: true) {
                            HStack(spacing: 16) {
                                // Original Image
                                if let original = selectedImage {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Original")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)

                                        Image(uiImage: original)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 250, height: 250)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                            .onTapGesture {
                                                fullscreenImageTitle = "Original"
                                                fullscreenImage = original
                                            }
                                    }
                                }

                                // Mask Image
                                if let mask = maskImage {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Mask")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)

                                        Image(uiImage: mask)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 250, height: 250)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                            .onTapGesture {
                                                fullscreenImageTitle = "Mask"
                                                fullscreenImage = mask
                                            }
                                    }
                                }

                                // Processed Image
                                if let processed = processedImage {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Result")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)

                                        Image(uiImage: processed)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 250, height: 250)
                                            .cornerRadius(12)
                                            .onTapGesture {
                                                fullscreenImageTitle = "Result"
                                                fullscreenImage = processed
                                            }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // Metrics Display
                if let metrics = lastMetrics {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Performance Metrics")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            MetricRow(title: "Inference Time", value: String(format: "%.2f ms", metrics.inferenceTimeMs))
                            MetricRow(title: "Memory Usage", value: String(format: "%.2f MB", metrics.memoryUsageMB))

                            if let loadTime = metrics.modelLoadTime {
                                MetricRow(title: "Model Load Time", value: String(format: "%.2f ms", loadTime * 1000))
                            }

                            MetricRow(title: "Cold Start", value: metrics.isColdStart ? "Yes" : "No")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .sheet(item: Binding(
            get: { fullscreenImage.map { FullscreenImageItem(image: $0, title: fullscreenImageTitle) } },
            set: { fullscreenImage = $0?.image }
        )) { item in
            FullscreenImageView(image: item.image, title: item.title)
        }
    }

    private func processImage() {
        guard let image = selectedImage else { return }

        isProcessing = true
        processedImage = nil
        maskImage = nil
        lastMetrics = nil

        Task {
            do {
                try await appState.selectedApproach.initialize()
                
                let removalResult = try await appState.selectedApproach.removeBackground(from: image)

                await MainActor.run {
                    isProcessing = false
                    processedImage = removalResult.processedImage
                    maskImage = removalResult.mask
                    lastMetrics = removalResult.metrics
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    print("Error: \(error.localizedDescription)")
                    // 🎯 TODO: Show error alert to user
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct CheckerboardPattern: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let squareSize: CGFloat = 10
                let rows = Int(ceil(size.height / squareSize))
                let cols = Int(ceil(size.width / squareSize))

                for row in 0..<rows {
                    for col in 0..<cols {
                        let isEven = (row + col) % 2 == 0
                        let rect = CGRect(
                            x: CGFloat(col) * squareSize,
                            y: CGFloat(row) * squareSize,
                            width: squareSize,
                            height: squareSize
                        )
                        context.fill(
                            Path(rect),
                            with: .color(isEven ? .white : .gray.opacity(0.3))
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Fullscreen Image View

struct FullscreenImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let title: String
}

struct FullscreenImageView: View {
    let image: UIImage
    let title: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Image Picker

// Simple Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ManualTestView()
        .environmentObject(AppState())
}
