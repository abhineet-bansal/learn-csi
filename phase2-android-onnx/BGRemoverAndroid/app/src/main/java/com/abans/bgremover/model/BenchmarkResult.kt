package com.abans.bgremover.model

data class BenchmarkResult(
    val approachName: String,
    val imageName: String,
    val imageSize: Pair<Int, Int>,
    val inferenceTimeMs: Double,
    val memoryUsageBytes: Long,
    val iou: Double?,
    val pixelAccuracy: Double?,
    val f1Score: Double?,
    val timestamp: Long = System.currentTimeMillis()
)
