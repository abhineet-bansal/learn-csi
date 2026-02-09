package com.abans.bgremover

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import com.abans.bgremover.service.LiteRTZoo2Approach
import com.abans.bgremover.service.LiteRTZooApproach
import com.abans.bgremover.service.VisionApiApproach
import com.abans.bgremover.ui.MainScreen
import com.abans.bgremover.ui.theme.BGRemoverTheme
import com.abans.bgremover.viewmodel.AppViewModel

class MainActivity : ComponentActivity() {

    private val viewModel: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Initialize approaches
        viewModel.initializeApproaches(listOf(
            VisionApiApproach(),
            LiteRTZooApproach(this.applicationContext),
            LiteRTZoo2Approach(this.applicationContext)
        ))

        setContent {
            BGRemoverTheme {
                MainScreen(viewModel)
            }
        }
    }
}