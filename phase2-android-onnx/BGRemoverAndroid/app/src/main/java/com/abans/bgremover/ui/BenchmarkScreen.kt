package com.abans.bgremover.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.abans.bgremover.service.BenchmarkRunner
import com.abans.bgremover.viewmodel.AppViewModel
import kotlinx.coroutines.launch

@Composable
fun BenchmarkScreen(viewModel: AppViewModel) {
    val approaches by viewModel.availableApproaches.collectAsState()
    val context = LocalContext.current
    val benchmarkRunner = remember { BenchmarkRunner(context) }

    val isRunning by benchmarkRunner.isRunning.collectAsState()
    val progress by benchmarkRunner.progress.collectAsState()
    val currentStatus by benchmarkRunner.currentStatus.collectAsState()
    val results by benchmarkRunner.results.collectAsState()

    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "Benchmark",
            style = MaterialTheme.typography.headlineMedium,
            modifier = Modifier.padding(bottom = 16.dp)
        )

        Button(
            onClick = {
                scope.launch {
                    benchmarkRunner.runBenchmarks(approaches)
                }
            },
            enabled = !isRunning && approaches.isNotEmpty(),
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 16.dp)
        ) {
            if (isRunning) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    color = MaterialTheme.colorScheme.onPrimary
                )
            } else {
                Text("Run Benchmark")
            }
        }

        if (isRunning) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Progress",
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    LinearProgressIndicator(
                        progress = { progress },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 8.dp)
                    )
                    Text(
                        text = currentStatus,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }

        if (results.isNotEmpty()) {
            Card(
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Results",
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )

                    val groupedResults = results.groupBy { it.approachName }

                    groupedResults.forEach { (approachName, approachResults) ->
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = approachName,
                            style = MaterialTheme.typography.titleSmall
                        )

                        val avgInferenceTime = approachResults.map { it.inferenceTime }.average()
                        val avgMemory = approachResults.map { it.memoryUsage }.average()
                        val avgIoU = approachResults.mapNotNull { it.iou }.average()
                        val avgPixelAccuracy = approachResults.mapNotNull { it.pixelAccuracy }.average()
                        val avgF1 = approachResults.mapNotNull { it.f1Score }.average()

                        Column(modifier = Modifier.padding(start = 16.dp, top = 8.dp)) {
                            Text("Images: ${approachResults.size}")
                            Text("Avg Inference Time: ${String.format("%.2f", avgInferenceTime * 1000)} ms")
                            Text("Avg Memory: ${String.format("%.2f", avgMemory / (1024.0 * 1024.0))} MB")
                            if (!avgIoU.isNaN()) {
                                Text("Avg IoU: ${String.format("%.4f", avgIoU)}")
                            }
                            if (!avgPixelAccuracy.isNaN()) {
                                Text("Avg Pixel Accuracy: ${String.format("%.4f", avgPixelAccuracy)}")
                            }
                            if (!avgF1.isNaN()) {
                                Text("Avg F1 Score: ${String.format("%.4f", avgF1)}")
                            }
                        }
                    }
                }
            }
        }
    }
}
