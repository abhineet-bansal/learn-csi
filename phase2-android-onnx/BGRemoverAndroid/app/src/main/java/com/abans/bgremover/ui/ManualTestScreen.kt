package com.abans.bgremover.ui

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.unit.dp
import com.abans.bgremover.model.BGRemovalResult
import com.abans.bgremover.viewmodel.AppViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun ManualTestScreen(viewModel: AppViewModel) {
    val approaches by viewModel.availableApproaches.collectAsState()
    val selectedApproach by viewModel.selectedApproach.collectAsState()

    var selectedImage by remember { mutableStateOf<Bitmap?>(null) }
    var result by remember { mutableStateOf<BGRemovalResult?>(null) }
    var isProcessing by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    val scope = rememberCoroutineScope()
    val pickImage = rememberImagePicker { bitmap ->
        selectedImage = bitmap
        result = null
        error = null
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "Manual Test",
            style = MaterialTheme.typography.headlineMedium,
            modifier = Modifier.padding(bottom = 16.dp)
        )

        if (approaches.isNotEmpty()) {
            SingleChoiceSegmentedButtonRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp)
            ) {
                approaches.forEachIndexed { index, approach ->
                    SegmentedButton(
                        selected = selectedApproach?.name == approach.name,
                        onClick = { viewModel.selectApproach(approach.name) },
                        shape = SegmentedButtonDefaults.itemShape(
                            index = index,
                            count = approaches.size
                        )
                    ) {
                        Text(approach.name)
                    }
                }
            }
        }

        Button(
            onClick = { pickImage() },
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 16.dp)
        ) {
            Text("Select Image")
        }

        selectedImage?.let { image ->
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Selected Image",
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    Image(
                        bitmap = image.asImageBitmap(),
                        contentDescription = "Selected",
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(200.dp)
                    )
                }
            }

            Button(
                onClick = {
                    scope.launch {
                        isProcessing = true
                        error = null
                        try {
                            val bgResult = withContext(Dispatchers.Default) {
                                selectedApproach?.let { approach ->
                                    if (!approach.isModelLoaded) {
                                        approach.initialize()
                                    }
                                    approach.removeBackground(image)
                                }
                            }
                            result = bgResult
                        } catch (e: Exception) {
                            error = e.message
                        } finally {
                            isProcessing = false
                        }
                    }
                },
                enabled = !isProcessing && selectedApproach != null,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp)
            ) {
                if (isProcessing) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                } else {
                    Text("Process Image")
                }
            }
        }

        error?.let { errorMsg ->
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp)
            ) {
                Text(
                    text = "Error: $errorMsg",
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(16.dp)
                )
            }
        }

        result?.let { bgResult ->
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Results",
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceEvenly
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("Processed", style = MaterialTheme.typography.labelSmall)
                            Image(
                                bitmap = bgResult.processedImage.asImageBitmap(),
                                contentDescription = "Processed",
                                modifier = Modifier.size(100.dp)
                            )
                        }
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("Mask", style = MaterialTheme.typography.labelSmall)
                            Image(
                                bitmap = bgResult.mask.asImageBitmap(),
                                contentDescription = "Mask",
                                modifier = Modifier.size(100.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    Text(
                        text = "Metrics",
                        style = MaterialTheme.typography.titleSmall,
                        modifier = Modifier.padding(bottom = 4.dp)
                    )
                    Text("Inference Time: ${String.format("%.2f", bgResult.metrics.inferenceTime * 1000)} ms")
                    Text("Memory Usage: ${String.format("%.2f", bgResult.metrics.peakMemoryUsage / (1024.0 * 1024.0))} MB")
                }
            }
        }
    }
}
