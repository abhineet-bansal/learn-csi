package com.abans.bgremover.model

import android.graphics.Bitmap

data class BGRemovalResult(
    val processedImage: Bitmap,
    val mask: Bitmap,
    val metrics: InferenceMetrics
)
