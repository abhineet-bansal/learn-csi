package com.abans.bgremover.service

import android.graphics.Bitmap
import com.abans.bgremover.model.BGRemovalResult

interface BGRemovalApproach {
    val name: String
    val isModelLoaded: Boolean

    suspend fun initialize()
    suspend fun removeBackground(image: Bitmap): BGRemovalResult
    fun cleanup()
}
