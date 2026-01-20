//
//  AppState.swift
//  BGRemover
//
//  Centralized app state management
//

import Foundation
import UIKit
internal import Combine

@MainActor
class AppState: ObservableObject {
    @Published var selectedApproach: BGRemovalApproach
    @Published var availableApproaches: [BGRemovalApproach]

    init() {
        // Initialize all three approaches
        let approaches: [BGRemovalApproach] = [
            VisionAPIApproach(),
            CoreMLApproach(),
            HuggingFaceApproach()
        ]

        self.availableApproaches = approaches
        self.selectedApproach = approaches[0]
    }

    func selectApproach(named name: String) {
        if let approach = availableApproaches.first(where: { $0.name == name }) {
            selectedApproach = approach
        }
    }
}
