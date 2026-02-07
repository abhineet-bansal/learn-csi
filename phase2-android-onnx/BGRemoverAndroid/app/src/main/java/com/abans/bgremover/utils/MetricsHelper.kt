package com.abans.bgremover.utils

import android.graphics.Bitmap

object MetricsHelper {

    fun getMemoryUsage(): Long {
        val runtime = Runtime.getRuntime()
        return runtime.totalMemory() - runtime.freeMemory()
    }

    fun calculateQualityMetrics(
        groundTruth: Bitmap,
        predicted: Bitmap,
        threshold: Float = 0.5f
    ): Triple<Double, Double, Double> {
        val gtPixels = ImageHelper.extractGrayscalePixels(groundTruth)
        val predPixels = ImageHelper.extractGrayscalePixels(predicted)

        var truePositive = 0
        var falsePositive = 0
        var trueNegative = 0
        var falseNegative = 0

        for (i in gtPixels.indices) {
            val gt = gtPixels[i] > threshold
            val pred = predPixels[i] > threshold

            when {
                gt && pred -> truePositive++
                !gt && pred -> falsePositive++
                !gt && !pred -> trueNegative++
                gt && !pred -> falseNegative++
            }
        }

        val iou = if (truePositive + falsePositive + falseNegative > 0) {
            truePositive.toDouble() / (truePositive + falsePositive + falseNegative)
        } else 0.0

        val pixelAccuracy = (truePositive + trueNegative).toDouble() / gtPixels.size

        val precision = if (truePositive + falsePositive > 0) {
            truePositive.toDouble() / (truePositive + falsePositive)
        } else 0.0

        val recall = if (truePositive + falseNegative > 0) {
            truePositive.toDouble() / (truePositive + falseNegative)
        } else 0.0

        val f1Score = if (precision + recall > 0) {
            2 * (precision * recall) / (precision + recall)
        } else 0.0

        return Triple(iou, pixelAccuracy, f1Score)
    }
}
