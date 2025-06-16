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
    
    let navigationTitle: String

    var body: some View {
        Color.clear
            .onAppear {
                if !countdownTimer.isComplete {
                    startNewAd()
                }
            }
            .onDisappear {
                countdownTimer.pause()
            }
            .onChange(of: countdownTimer.isComplete) {
                if countdownTimer.isComplete {
                    viewModel.showInterstitialAd()
                }
            }
    }

    private func startNewAd() {
        countdownTimer.start()
        Task {
            await viewModel.loadAd()
        }
    }
}

//#Preview {
//    InterstitialContentView()
//}
