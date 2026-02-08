package com.abans.bgremover.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

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
                    withContext(Dispatchers.Default) {
                        benchmarkRunner.runBenchmarks(approaches)
                    }
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
            Column(modifier = Modifier.padding(horizontal = 16.dp)) {
                Text(
                    text = "Results (${results.size})",
                    style = MaterialTheme.typography.headlineSmall,
                    modifier = Modifier.padding(bottom = 16.dp)
                )

                val groupedResults = results.groupBy { it.approachName }

                groupedResults.forEach { (approachName, approachResults) ->
                    BenchmarkResultCard(
                        approachName = approachName,
                        results = approachResults
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                }
            }
        }
    }
}

@Composable
fun BenchmarkResultCard(
    approachName: String,
    results: List<com.abans.bgremover.model.BenchmarkResult>
) {
    val avgInferenceTime = results.map { it.inferenceTime }.average()
    val avgMemory = results.map { it.memoryUsage }.average()
    val avgIoU = results.mapNotNull { it.iou }.takeIf { it.isNotEmpty() }?.average()
    val avgPixelAccuracy = results.mapNotNull { it.pixelAccuracy }.takeIf { it.isNotEmpty() }?.average()
    val avgF1 = results.mapNotNull { it.f1Score }.takeIf { it.isNotEmpty() }?.average()

    Card(
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = approachName,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(bottom = 12.dp)
            )

            // Performance Metrics Row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                MetricCell(
                    title = "Avg Inference",
                    value = String.format("%.2f ms", avgInferenceTime * 1000),
                    modifier = Modifier.weight(1f)
                )
                MetricCell(
                    title = "Avg Memory",
                    value = String.format("%.2f MB", avgMemory / (1024.0 * 1024.0)),
                    modifier = Modifier.weight(1f)
                )
                MetricCell(
                    title = "Images",
                    value = "${results.size}",
                    modifier = Modifier.weight(1f)
                )
            }

            // Quality Metrics Row (if available)
            if (avgIoU != null || avgPixelAccuracy != null || avgF1 != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    MetricCell(
                        title = "Avg IoU",
                        value = avgIoU?.let { String.format("%.4f", it) } ?: "N/A",
                        modifier = Modifier.weight(1f)
                    )
                    MetricCell(
                        title = "Avg Pixel Accuracy",
                        value = avgPixelAccuracy?.let { String.format("%.4f", it) } ?: "N/A",
                        modifier = Modifier.weight(1f)
                    )
                    MetricCell(
                        title = "Avg F1 Score",
                        value = avgF1?.let { String.format("%.4f", it) } ?: "N/A",
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
    }
}

@Composable
fun MetricCell(
    title: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = androidx.compose.ui.text.font.FontWeight.Medium
        )
    }
}
