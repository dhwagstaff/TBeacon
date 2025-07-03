//
//  DirectRewardedAdView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 7/2/25.
//

import GoogleMobileAds
import SwiftUI

struct DirectRewardedAdView: View {
    @StateObject private var viewModel = RewardedInterstitialViewModel()
    
    @State private var showAdDialog = false
    @State private var showAd = false
    @State private var showAdErrorAlert = false
    
    @Binding var isPresented: Bool
    
    var onAdCompleted: (() -> Void)?

    var body: some View {
        ZStack {
            // Show the ad dialog immediately
            if showAdDialog {
                AdDialogContentView(
                    isPresenting: $showAdDialog,
                    countdownComplete: $showAd,
                    onSkip: {
                        // Dismiss the entire view when user skips
                        isPresented = false
                    }
                )
            }
        }
        .alert(isPresented: $showAdErrorAlert) {
            Alert(
                title: Text("Ad Not Available"),
                message: Text("No ad is available right now. Please try again later."),
                dismissButton: .default(Text("OK")) {
                    isPresented = false
                }
            )
        }
        .onAppear {
            // Show the ad dialog immediately when this view appears
            showAdDialog = true
            
            viewModel.onAdFailedToShow = {
                showAdErrorAlert = true
            }
        }
        .onChange(of: viewModel.isAdCompleted) {
            if viewModel.isAdCompleted {
                onAdCompleted?()
                
                isPresented = false
            }
        }
        .onChange(of: showAd) {
            if showAd {
                viewModel.showRewardedAd()
            }
        }
        .onAppear {
            // Load the ad when view appears
            Task {
                await viewModel.loadAd()
            }
        }
    }
}
//#Preview {
//    DirectRewardedAdView()
//}
