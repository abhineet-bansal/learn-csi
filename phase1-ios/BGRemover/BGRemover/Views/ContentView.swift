//
//  ContentView.swift
//  BGRemover
//
//  Created by Abhineet Bansal on 27/1/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        TabView {
            ManualTestView()
                .tabItem {
                    Label("Manual Test", systemImage: "wand.and.stars")
                }
                .environmentObject(appState)

            BenchmarkView()
                .tabItem {
                    Label("Benchmark", systemImage: "chart.bar.fill")
                }
                .environmentObject(appState)
        }
    }
}

#Preview {
    ContentView()
}
