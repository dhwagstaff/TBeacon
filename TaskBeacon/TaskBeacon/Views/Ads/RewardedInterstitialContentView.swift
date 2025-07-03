//
//  Copyright 2022 Google LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import GoogleMobileAds
import SwiftUI

struct RewardedInterstitialContentView: View {
    @StateObject private var viewModel = RewardedInterstitialViewModel()
    @StateObject private var countdownTimer = CountdownTimer(10)
    
    @State private var showAdDialog = false
    @State private var showAd = false
    @State private var isAdReady = false
    @State private var showAdErrorAlert = false

    @Binding var isPresented: Bool
    
    let navigationTitle: String

    var body: some View {
        ZStack {
            rewardedInterstitialBody

            if showAdDialog {
                AdDialogContentView(isPresenting: $showAdDialog, countdownComplete: $showAd, onSkip: {
                    isPresented = false
                })
                .opacity(showAdDialog ? 1 : 0)
            }
        }
        .alert(isPresented: $showAdErrorAlert) {
            Alert(
                title: Text("Ad Not Available"),
                message: Text("No ad is available right now. Please try again later."),
                dismissButton: .default(Text("OK")) {
                    isPresented = false // Dismiss the RewardedInterstitialContentView
                    showAdDialog = false // Dismiss AdDialogContentView if needed
                }
            )
        }
        .onAppear {
            viewModel.onAdFailedToShow = {
                showAdErrorAlert = true
            }
        }
        .onChange(of: viewModel.isAdCompleted) {
            if viewModel.isAdCompleted {
                isPresented = false
            }
        }
    }

    var rewardedInterstitialBody: some View {
        VStack() {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 2)
                .padding([.top, .bottom], 8)
            
            Text("Echolist Rewards")
                .font(.title)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "FFD300"), Color(hex: "005D5D").opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(maxWidth: .infinity)
            
            RewardAnimationImageView()

            Text("Complete tasks to earn rewards!")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding()

            Text("Watch an ad to earn an Extra To-Do or Shopping Item")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
            
            Spacer()

            Button(action: {
                showAdDialog = true
            }) {
                Text("Watch Ad")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "1240AB"))
                    .cornerRadius(10)
            }
            .padding()
            
            Button(action: {
                isPresented = false
            }) {
                Text("No Thanks")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "5777C0"))
                    .cornerRadius(10)
            }
            .padding()

            Spacer()

            HStack {
                Text("Tasks: \(viewModel.coins)")
                    .font(.headline)
                Spacer()
            }
            .padding()
        }
        .onAppear {
            startNewAd()
        }
        .onDisappear {
            countdownTimer.pause()
        }
        .onChange(of: showAd) {
            if showAd {
                viewModel.showRewardedAd()
            }
        }
        .navigationTitle(navigationTitle)
    }

    private func startNewAd() {
        countdownTimer.start()
        Task {
            await viewModel.loadAd()
            
            isAdReady = true
        }
    }
}

struct RewardAnimationImageView: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 180)
                .foregroundColor(Color(hex: "735AC4"))
                .background(.white)
                .rotationEffect(.degrees(-50 + rotation))
                .transition(.scale.combined(with: .opacity))
            
            HStack(spacing: 20) {
                ZStack {
                    Image(systemName: "cart")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(Color(hex: "FFD300"))
                        .background(.white)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Text("OR")
                    .font(.headline)
                    .foregroundColor(Color(hex: "5777C0"))
                
                ZStack {
                    Image(systemName: "checklist")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(Color(hex: "005D5D"))
                        .background(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

struct RewardedIntersititalContentView_Previews: PreviewProvider {
  static var previews: some View {
      RewardedInterstitialContentView(isPresented: .constant(false), navigationTitle: "Rewarded Interstitial")
  }
}
