package com.abans.bgremover.viewmodel

import androidx.lifecycle.ViewModel
import com.abans.bgremover.service.BGRemovalApproach
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class AppViewModel : ViewModel() {

    private val _availableApproaches = MutableStateFlow<List<BGRemovalApproach>>(emptyList())
    val availableApproaches: StateFlow<List<BGRemovalApproach>> = _availableApproaches.asStateFlow()

    private val _selectedApproach = MutableStateFlow<BGRemovalApproach?>(null)
    val selectedApproach: StateFlow<BGRemovalApproach?> = _selectedApproach.asStateFlow()

    fun initializeApproaches(approaches: List<BGRemovalApproach>) {
        _availableApproaches.value = approaches
        if (approaches.isNotEmpty()) {
            _selectedApproach.value = approaches[0]
        }
    }

    fun selectApproach(approachName: String) {
        _selectedApproach.value = _availableApproaches.value.find { it.name == approachName }
    }

    override fun onCleared() {
        super.onCleared()
        _availableApproaches.value.forEach { it.cleanup() }
    }
}
