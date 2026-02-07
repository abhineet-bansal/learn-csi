package com.abans.bgremover.service

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.abans.bgremover.model.BenchmarkResult
import com.abans.bgremover.utils.ImageHelper
import com.abans.bgremover.utils.MetricsHelper
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class TestImage(
    val name: String,
    val image: Bitmap,
    val groundTruth: Bitmap?
)

class BenchmarkRunner(private val context: Context) {

    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning.asStateFlow()

    private val _progress = MutableStateFlow(0f)
    val progress: StateFlow<Float> = _progress.asStateFlow()

    private val _currentStatus = MutableStateFlow("")
    val currentStatus: StateFlow<String> = _currentStatus.asStateFlow()

    private val _results = MutableStateFlow<List<BenchmarkResult>>(emptyList())
    val results: StateFlow<List<BenchmarkResult>> = _results.asStateFlow()

    companion object {
        const val ITERATIONS = 3
    }

    suspend fun runBenchmarks(approaches: List<BGRemovalApproach>) {
        _isRunning.value = true
        _results.value = emptyList()
        _progress.value = 0f

        val testImages = loadTestImages()
        if (testImages.isEmpty()) {
            _currentStatus.value = "Error: No test images found"
            _isRunning.value = false
            return
        }

        val totalRuns = approaches.size * testImages.size * ITERATIONS
        var completedRuns = 0

        val resultsList = mutableListOf<BenchmarkResult>()

        for (approach in approaches) {
            _currentStatus.value = "Initializing ${approach.name}..."

            try {
                approach.initialize()
            } catch (e: Exception) {
                _currentStatus.value = "Error initializing ${approach.name}: ${e.message}"
                continue
            }

            for (testImage in testImages) {
                val iterationResults = mutableListOf<BenchmarkResult>()

                for (iteration in 1..ITERATIONS) {
                    _currentStatus.value = "Testing ${approach.name} on ${testImage.name} (iteration $iteration/$ITERATIONS)..."

                    try {
                        val removalResult = approach.removeBackground(testImage.image)

                        var iou: Double? = null
                        var pixelAccuracy: Double? = null
                        var f1Score: Double? = null

                        if (testImage.groundTruth != null) {
                            val resizedMask = ImageHelper.resizeBitmap(
                                removalResult.mask,
                                testImage.groundTruth.width,
                                testImage.groundTruth.height
                            )
                            val qualityMetrics = MetricsHelper.calculateQualityMetrics(
                                testImage.groundTruth,
                                resizedMask
                            )
                            iou = qualityMetrics.first
                            pixelAccuracy = qualityMetrics.second
                            f1Score = qualityMetrics.third
                        }

                        val benchmarkResult = BenchmarkResult(
                            approachName = approach.name,
                            imageName = testImage.name,
                            imageSize = Pair(testImage.image.width, testImage.image.height),
                            inferenceTime = removalResult.metrics.inferenceTime,
                            memoryUsage = removalResult.metrics.peakMemoryUsage,
                            iou = iou,
                            pixelAccuracy = pixelAccuracy,
                            f1Score = f1Score
                        )

                        iterationResults.add(benchmarkResult)
                    } catch (e: Exception) {
                        _currentStatus.value = "Error processing ${testImage.name} with ${approach.name}: ${e.message}"
                    }

                    completedRuns++
                    _progress.value = completedRuns.toFloat() / totalRuns
                }

                // Use median result
                val medianResult = iterationResults.sortedBy { it.inferenceTime }
                    .getOrNull(ITERATIONS / 2)
                if (medianResult != null) {
                    resultsList.add(medianResult)
                }
            }

            approach.cleanup()
        }

        _results.value = resultsList
        _currentStatus.value = "Benchmark complete! Processed $completedRuns runs."
        _isRunning.value = false

        printSummary(resultsList)
    }

    private fun loadTestImages(): List<TestImage> {
        val testImages = mutableListOf<TestImage>()

        for (i in 1..30) {
            val imageNum = String.format("%02d", i)
            val imageName = "img$imageNum"
            val maskName = "mask$imageNum"

            try {
                val imageStream = context.assets.open("$imageName.jpg")
                val image = BitmapFactory.decodeStream(imageStream)
                imageStream.close()

                var groundTruth: Bitmap? = null
                try {
                    val maskStream = context.assets.open("$maskName.png")
                    groundTruth = BitmapFactory.decodeStream(maskStream)
                    maskStream.close()
                } catch (e: Exception) {
                    // Ground truth not available for this image
                }

                testImages.add(TestImage(imageName, image, groundTruth))
            } catch (e: Exception) {
                // Image not found, skip
            }
        }

        return testImages
    }

    private fun printSummary(results: List<BenchmarkResult>) {
        println("=" .repeat(80))
        println("BENCHMARK SUMMARY")
        println("=" .repeat(80))

        val groupedByApproach = results.groupBy { it.approachName }

        for ((approach, approachResults) in groupedByApproach.entries.sortedBy { it.key }) {
            println("\n📱 $approach")
            println("-" .repeat(80))

            val avgInference = approachResults.map { it.inferenceTime }.average()
            val avgMemory = approachResults.map { it.memoryUsage.toDouble() }.average()

            println(String.format("  Avg Inference Time: %.2f ms", avgInference * 1000))
            println(String.format("  Avg Memory Usage: %.2f MB", avgMemory / (1024.0 * 1024.0)))

            val resultsWithQuality = approachResults.filter {
                it.iou != null && it.pixelAccuracy != null && it.f1Score != null
            }

            if (resultsWithQuality.isNotEmpty()) {
                val avgIoU = resultsWithQuality.mapNotNull { it.iou }.average()
                val avgPixelAccuracy = resultsWithQuality.mapNotNull { it.pixelAccuracy }.average()
                val avgF1Score = resultsWithQuality.mapNotNull { it.f1Score }.average()

                println(String.format("  Avg IoU: %.4f", avgIoU))
                println(String.format("  Avg Pixel Accuracy: %.4f", avgPixelAccuracy))
                println(String.format("  Avg F1 Score: %.4f", avgF1Score))
            }
        }

        println("\n" + "=" .repeat(80))
    }
}
