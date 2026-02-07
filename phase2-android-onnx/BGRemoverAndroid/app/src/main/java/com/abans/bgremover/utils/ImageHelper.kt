package com.abans.bgremover.utils

import android.graphics.Bitmap
import android.graphics.Color

object ImageHelper {

    fun applyMask(image: Bitmap, mask: Bitmap): Bitmap {
        val result = Bitmap.createBitmap(image.width, image.height, Bitmap.Config.ARGB_8888)

        for (y in 0 until image.height) {
            for (x in 0 until image.width) {
                val pixel = image.getPixel(x, y)
                val maskPixel = mask.getPixel(x, y)
                val alpha = Color.red(maskPixel)

                val newPixel = Color.argb(
                    alpha,
                    Color.red(pixel),
                    Color.green(pixel),
                    Color.blue(pixel)
                )
                result.setPixel(x, y, newPixel)
            }
        }

        return result
    }

    fun extractGrayscalePixels(bitmap: Bitmap): FloatArray {
        val pixels = FloatArray(bitmap.width * bitmap.height)

        for (y in 0 until bitmap.height) {
            for (x in 0 until bitmap.width) {
                val pixel = bitmap.getPixel(x, y)
                val gray = Color.red(pixel) / 255f
                pixels[y * bitmap.width + x] = gray
            }
        }

        return pixels
    }

    fun resizeBitmap(bitmap: Bitmap, width: Int, height: Int): Bitmap {
        return Bitmap.createScaledBitmap(bitmap, width, height, true)
    }
}
