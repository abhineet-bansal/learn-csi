package com.abans.bgremover.service

import android.graphics.Bitmap
import android.graphics.Color
import com.abans.bgremover.model.BGRemovalResult
import com.abans.bgremover.model.InferenceMetrics
import com.abans.bgremover.utils.ImageHelper
import com.abans.bgremover.utils.MetricsHelper
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentationResult
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenter
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import kotlinx.coroutines.tasks.await
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.IntBuffer

class VisionApiApproach : BGRemovalApproach {
    override val name: String = "Vision API"

    @Volatile
    private var _isModelLoaded = false
    override val isModelLoaded: Boolean
        get() = _isModelLoaded

    private var _subjectSegmenter: SubjectSegmenter? = null

    override suspend fun initialize() {
        if (_isModelLoaded)
            return

        val options = SubjectSegmenterOptions.Builder()
            .enableForegroundConfidenceMask()
            .build()

        _subjectSegmenter = SubjectSegmentation.getClient(options)
        _isModelLoaded = true
    }

    override suspend fun removeBackground(image: Bitmap): BGRemovalResult {
        val segmenter = _subjectSegmenter ?: throw IllegalStateException("Model not initialized")

        val inputImage = InputImage.fromBitmap(image, 0)

        val startTime = System.nanoTime()
        val memoryBefore = MetricsHelper.getMemoryUsage()
        val segmentationResult = segmenter.process(inputImage).await()
        val inferenceTimeMs = (System.nanoTime() - startTime) / 1000000.0

        val mask = postprocess(image, segmentationResult)
        val processedImage = ImageHelper.applyMask(image, mask)
        val memoryAfter = MetricsHelper.getMemoryUsage()
        val peakMemoryBytes = (memoryAfter - memoryBefore).coerceAtLeast(0)

        val metrics = InferenceMetrics(inferenceTimeMs, peakMemoryBytes)
        val bgRemovalResult = BGRemovalResult(processedImage, mask, metrics)
        return bgRemovalResult
    }

    override fun cleanup() {
        _subjectSegmenter?.close()
        _subjectSegmenter = null
        _isModelLoaded = false
    }

    private fun postprocess(originalImage: Bitmap, segmentationResult: SubjectSegmentationResult): Bitmap {
        val foregroundMask =
            segmentationResult.foregroundConfidenceMask ?: throw IllegalStateException("Empty mask received")

        val width = originalImage.width
        val height = originalImage.height

        // Approach #1:
        /*
        val maskPixels = IntArray(width * height)
        for (i in 0 until width * height) {
            val confidence = foregroundMask[i]
            val alpha = if (confidence > 0.5f) {
                (confidence * 255).toInt()
            } else {
                0
            }
            maskPixels[i] = Color.argb(alpha, 255, 255, 255)
        }

        return Bitmap.createBitmap(maskPixels, width, height, Bitmap.Config.ARGB_8888)
         */

        // Create bitmap directly - no intermediate array
        val maskBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)

        // Approach #2
        // Write directly to bitmap buffer
        /*
        val buffer = IntBuffer.allocate(width) // Reusable row buffer
        for (y in 0 until height) {
            buffer.clear()
            for (x in 0 until width) {
                val idx = y * width + x
                val confidence = foregroundMask[idx]
                val alpha = if (confidence > 0.5f) (confidence * 255).toInt() else 0
                buffer.put(Color.argb(alpha, 255, 255, 255))
            }
            buffer.rewind()
            maskBitmap.setPixels(buffer.array(), 0, width, 0, y, width, 1)
        }
         */

        // Approach #3
        // Direct buffer access
        val buffer = ByteBuffer.allocateDirect(width * height * 4)
        buffer.order(ByteOrder.nativeOrder())

        for (i in 0 until width * height) {
            val confidence = foregroundMask[i]
            val alpha = if (confidence > 0.5f) (confidence * 255).toInt().toByte() else 0

            buffer.put(alpha)      // A
            buffer.put(0xFF.toByte()) // R
            buffer.put(0xFF.toByte()) // G
            buffer.put(0xFF.toByte()) // B
        }

        buffer.rewind()
        maskBitmap.copyPixelsFromBuffer(buffer)

        return maskBitmap
    }
}