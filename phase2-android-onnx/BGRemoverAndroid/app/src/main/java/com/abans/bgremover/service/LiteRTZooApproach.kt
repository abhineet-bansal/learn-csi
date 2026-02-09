package com.abans.bgremover.service

import android.content.Context
import android.graphics.Bitmap
import com.abans.bgremover.model.BGRemovalResult
import com.abans.bgremover.model.InferenceMetrics
import com.abans.bgremover.utils.ImageHelper
import com.abans.bgremover.utils.MetricsHelper
import com.google.ai.edge.litert.Accelerator
import com.google.ai.edge.litert.CompiledModel
import com.google.ai.edge.litert.TensorBuffer
import org.tensorflow.lite.DataType
import org.tensorflow.lite.support.common.ops.NormalizeOp
import org.tensorflow.lite.support.image.ImageProcessor
import org.tensorflow.lite.support.image.TensorImage
import org.tensorflow.lite.support.image.ops.ResizeOp
import androidx.core.graphics.scale

class LiteRTZooApproach(applicationContext: Context) : BGRemovalApproach {
    override val name: String = "Lite RT Model Zoo"

    @Volatile
    private var _isModelLoaded = false
    override val isModelLoaded: Boolean
        get() = _isModelLoaded

    private var _context: Context? = null
    private var _model: CompiledModel? = null

    init {
        _context = applicationContext
    }

    override suspend fun initialize() {
        if (_isModelLoaded)
            return

        _model =
            CompiledModel.create(
                _context!!.assets,
                "tensorflow_deeplabv3.tflite",
                CompiledModel.Options(Accelerator.CPU)
            )

        _isModelLoaded = true
    }

    override suspend fun removeBackground(image: Bitmap): BGRemovalResult {
        val model = _model ?: throw IllegalStateException("Model not initialized")

        val inputBuffers = preprocess(image, model)
        val outputBuffers = model.createOutputBuffers()

        val startTime = System.nanoTime()
        val memoryBefore = MetricsHelper.getMemoryUsage()

        model.run(inputBuffers, outputBuffers)

        val inferenceTimeMs = (System.nanoTime() - startTime) / 1000000.0

        val mask = postprocess(image, outputBuffers)

        val processedImage = ImageHelper.applyMask(image, mask)

        val memoryAfter = MetricsHelper.getMemoryUsage()
        val peakMemoryBytes = (memoryAfter - memoryBefore).coerceAtLeast(0)

        val metrics = InferenceMetrics(inferenceTimeMs, peakMemoryBytes)
        val bgRemovalResult = BGRemovalResult(processedImage, mask, metrics)
        return bgRemovalResult
    }

    override fun cleanup() {
        _model = null
        _isModelLoaded = false
    }

    private fun preprocess(image: Bitmap, model: CompiledModel): List<TensorBuffer> {
        val image = ImageHelper.validateSoftwareBitmap(image)

        // Create support API's TensorImage for easy resizing, normalizing and access to buffer
        val tensorImage = TensorImage(DataType.FLOAT32)
        tensorImage.load(image)

        val imageProcessor = ImageProcessor.Builder()
            .add(ResizeOp(257, 257, ResizeOp.ResizeMethod.BILINEAR))
            .add(NormalizeOp(0.0f, 255.0f))           // Normalise [0, 255] to [0, 1]
            .build()

        val processedInputImage = imageProcessor.process(tensorImage)
        val inputTensorBuffer = processedInputImage.tensorBuffer
        // Support library (org.tensorflow.lite.support.tensorbuffer) provides TensorImage
        // this library also has a TensorBuffer class, returned by TensorImage.tensorBuffer
        // This TensorBuffer class is different to the LiteRT package's TensorBuffer (com.google.ai.edge.litert.TensorBuffer)

        val inputBuffers = model.createInputBuffers()
        inputBuffers[0].writeFloat(inputTensorBuffer.floatArray)

        return inputBuffers
    }

    private fun postprocess(originalImage: Bitmap, outputBuffers: List<TensorBuffer>): Bitmap {
        // Data type and shape of the TensorBuffer is needed to create a tensor image
        // But those are not available in the new TensorBuffer class - https://ai.google.dev/edge/api/litert/kotlin/com/google/ai/edge/litert/TensorBuffer
        // Hardcoding the same and data type from model inspection details
        val outputBuffer = outputBuffers[0]
        val floatArray = outputBuffer.readFloat()

        // The shape of output buffer is [1, 257, 257, 21]
        // Meaning - 257 x 257 array (row indexed). For each pixel, the 21 values are probabilities of each class
        // Class 0 is background, and other classes are object types

        val maskArray = ByteArray(257 * 257)

        for (row in 0 until 257) {
            for (col in 0 until 257) {
                val index = ((row * 257) + col) * 21 // Start of this pixel's 21 values

                // Find the class with the max probability
                var maxClass = 0
                var maxProb = floatArray[index]
                for (classIdx in 1 until 21) {
                    if (floatArray[index + classIdx] > maxProb) {
                        maxProb = floatArray[index + classIdx]
                        maxClass = classIdx
                    }
                }

                maskArray[row * 257 + col] = if (maxClass == 0) 0 else 1
            }
        }

        // Convert byte mask (0 or 1) to ARGB pixels (black or white)
        val pixels = IntArray(257 * 257)
        for (i in maskArray.indices) {
            // 0 -> black (0xFF000000), 1 -> white (0xFFFFFFFF)
            pixels[i] = if (maskArray[i] == 0.toByte()) 0xFF000000.toInt() else 0xFFFFFFFF.toInt()
        }

        // Create 257x257 mask bitmap from pixel array
        val maskBitmap = Bitmap.createBitmap(pixels, 257, 257, Bitmap.Config.ARGB_8888)

        // Resize to original image dimensions
        val resizedMask = maskBitmap.scale(originalImage.width, originalImage.height)

        maskBitmap.recycle()

        return resizedMask
    }
}