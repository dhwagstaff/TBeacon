//
//  InterstitialContentView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/14/25.
//

import SwiftUI

struct InterstitialContentView: View {
    @StateObject private var viewModel = InterstitialViewModel()
    
    @StateObject private var countdownTimer = CountdownTimer(10)
    
    @Binding var isPresented: Bool
    
    let navigationTitle: String
    
    @State private var isAdReady = false

    var body: some View {
        Color(.systemBackground)
            .edgesIgnoringSafeArea(.all)
        
        VStack {
            ProgressView()
            Text("Loading Ad...")
                .padding(.top, 8)
                .foregroundColor(.secondary)
        }
        .onAppear {
            if !isAdReady {
                startNewAd()
            }
        }
        .onDisappear {
            countdownTimer.pause()
        }
        .onChange(of: countdownTimer.isComplete) {
            if countdownTimer.isComplete && isAdReady {
                viewModel.showInterstitialAd()
            }
        }
    }

    private func startNewAd() {
        // Don't start countdown immediately - wait for ad to be ready
        viewModel.loadAndShowAd(
            onDismissed: {
                self.countdownTimer.pause()
                self.isPresented = false
            },
            onAdReady: {
                // Only start countdown when ad is actually ready
                self.isAdReady = true
                self.countdownTimer.start()
            },
            onAdFailed: {
                // Dismiss immediately if ad fails
                self.isPresented = false
            }
        )
    }
}

//#Preview {
//    InterstitialContentView()
//}
