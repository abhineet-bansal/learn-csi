package com.abans.bgremover.utils

import android.graphics.Bitmap
import android.graphics.Color
import androidx.core.graphics.createBitmap
import androidx.core.graphics.get
import androidx.core.graphics.set

object ImageHelper {

    fun applyMask(image: Bitmap, mask: Bitmap): Bitmap {
        val image = validateSoftwareBitmap(image)
        val mask = validateSoftwareBitmap(mask)

        val result = createBitmap(image.width, image.height)

        for (y in 0 until image.height) {
            for (x in 0 until image.width) {
                val pixel = image[x, y]
                val maskPixel = mask[x, y]
                val alpha = Color.red(maskPixel)

                val newPixel = Color.argb(
                    alpha,
                    Color.red(pixel),
                    Color.green(pixel),
                    Color.blue(pixel)
                )
                result[x, y] = newPixel
            }
        }

        return result
    }

    fun extractGrayscalePixels(bitmap: Bitmap): FloatArray {
        val bitmap = validateSoftwareBitmap(bitmap)

        val pixels = FloatArray(bitmap.width * bitmap.height)

        for (y in 0 until bitmap.height) {
            for (x in 0 until bitmap.width) {
                val pixel = bitmap[x, y]
                val gray = Color.red(pixel) / 255f
                pixels[y * bitmap.width + x] = gray
            }
        }

        return pixels
    }

    fun validateSoftwareBitmap(bitmap: Bitmap): Bitmap {
        if (bitmap.config == Bitmap.Config.HARDWARE)
            return bitmap.copy(Bitmap.Config.ARGB_8888, false)

        return bitmap
    }
}
