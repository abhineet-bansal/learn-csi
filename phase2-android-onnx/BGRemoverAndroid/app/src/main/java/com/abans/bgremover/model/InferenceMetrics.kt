package com.abans.bgremover.model

data class InferenceMetrics(
    val inferenceTime: Double,  // in seconds
    val peakMemoryUsage: Long   // in bytes
)
