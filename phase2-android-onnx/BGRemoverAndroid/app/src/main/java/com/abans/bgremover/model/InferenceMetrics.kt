package com.abans.bgremover.model

data class InferenceMetrics(
    val inferenceTimeMs: Double,  // in milli seconds
    val peakMemoryUsageBytes: Long   // in bytes
)
