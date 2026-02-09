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
import kotlin.math.roundToInt

// Using google deep lab edge tpu model
class LiteRTZoo2Approach(applicationContext: Context) : BGRemovalApproach {
    override val name: String = "Google DeepLab EdgeTPU"

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
                "google_deeplab_edgetpu.tflite",
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

        // Input 'shape': array([  1, 512, 512,   3]
        // 'dtype': <class 'numpy.int8'>
        // 'quantization_parameters': {
        //      'scales': array([0.00784314], dtype=float32)
        //      'zero_points': array([-1], dtype=int32),
        //      'quantized_dimension': 0
        //  }

        // Thus, float32 -> int8 conversion formula:
        // int8_value = round(float_value / `scale`) + `zero_point` = round(float_value / 0.00784314) - 1
        // Pixel 0 => float_value = 0 / 255.0 = 0.0 => int8_value = -1
        // Pixel 128 => float_value = 128.0 / 255.0 = 0.5 => int8_value = 62
        // Pixel 255 => float_value = 255.0 / 255.0 = 1.0 => int8_value = 126

        // So, we need to Normalise [0, 255] to [-1, 126]

        // Create support API's TensorImage for easy resizing, normalizing and access to buffer
        val tensorImage = TensorImage(DataType.UINT8)
        tensorImage.load(image)

        val imageProcessor = ImageProcessor.Builder()
            .add(ResizeOp(512, 512, ResizeOp.ResizeMethod.BILINEAR))
            .build()

        val processedInputImage = imageProcessor.process(tensorImage)
        val byteBuffer = processedInputImage.buffer

        // Manually quantize [0, 255] → [-1, 126]
        val quantizedArray = ByteArray(byteBuffer.capacity())
        for (i in quantizedArray.indices) {
            val pixel = byteBuffer.get(i).toInt() and 0xFF  // Convert to unsigned [0, 255]

            val normalized = pixel / 255.0f
            val quantizedValue = (normalized / 0.00784314f).roundToInt() - 1
            quantizedArray[i] = quantizedValue.toByte()
        }

        // Write quantized int8 data
        val inputBuffers = model.createInputBuffers()
        inputBuffers[0].writeInt8(quantizedArray)

        return inputBuffers
    }

    private fun postprocess(originalImage: Bitmap, outputBuffers: List<TensorBuffer>): Bitmap {
        // Data type and shape of the TensorBuffer is needed to create a tensor image
        // But those are not available in the new TensorBuffer class - https://ai.google.dev/edge/api/litert/kotlin/com/google/ai/edge/litert/TensorBuffer
        // Hardcoding the same and data type from model inspection details
        val outputBuffer = outputBuffers[0]
        val floatArray = outputBuffer.readFloat()

        // The shape of output buffer is [1, 512, 512]
        // Meaning - 512 x 512 array (row indexed). For each pixel, the class with highest probability is provided
        // Argmax for all the classes has already been applied
        // Class 0 is background, and other classes are object types
        // 'dtype': <class 'numpy.float32'>
        val width = 512
        val height = 512

        val maskArray = ByteArray(width * height)

        for (row in 0 until height) {
            for (col in 0 until width) {
                val index = (row * height) + col

                val pixelClass = floatArray[index].toInt()

                // There is no class 0 with any test images, so I tried class 1 as background and that worked better
                maskArray[index] = if (pixelClass == 1) 0 else 1
            }
        }

        // Convert byte mask (0 or 1) to ARGB pixels (black or white)
        val pixels = IntArray(width * height)
        for (i in maskArray.indices) {
            // 0 -> black (0xFF000000), 1 -> white (0xFFFFFFFF)
            pixels[i] = if (maskArray[i] == 0.toByte()) 0xFF000000.toInt() else 0xFFFFFFFF.toInt()
        }

        // Create 512x512 mask bitmap from pixel array
        val maskBitmap = Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)

        // Resize to original image dimensions
        val resizedMask = maskBitmap.scale(originalImage.width, originalImage.height)

        maskBitmap.recycle()

        return resizedMask
    }
}