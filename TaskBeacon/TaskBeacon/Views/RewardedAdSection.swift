//
//  RewardedAdSection.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/5/25.
//

import SwiftUI

struct RewardedAdSection: View {
    @Binding var showAd: Bool
    @Binding var isAdReady: Bool

    @State private var elapsedTime: TimeInterval = 0
    @State private var showLoadingMessage = false
    @State private var rotationAngle: Double = 0

    var adManager: AdManager

    var body: some View {
        VStack {
            if adManager.isAdReady {
                Text("Task Beacon Rewards")
                    .font(.title)
                    .padding()

                Button("Watch Ad for Extra To-Do") {
                    if adManager.canShowAd() {
                        print("🚀 Button Pressed: Setting showAd = true")
                        DispatchQueue.main.async {
                            showAd = true
                        }
                    } else {
                        print("⏳ Ad is still in cooldown. Please wait...")
                    }
                }
                .padding()
                .background(Color.accentColor) // ✅ adaptive theme color
                .foregroundColor(.white)
                .cornerRadius(10)

            } else if showLoadingMessage {
                VStack {
                    Image(systemName: "hourglass")
                        .font(.system(size: 50))
                        .rotationEffect(.degrees(rotationAngle))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotationAngle)
                        .onAppear {
                            rotationAngle = 360
                        }

                    Text("⏳ Loading ad...")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
        }
        .onAppear {
            print("⏳ Tracking ad availability...")
            resetAdState()
        }
        .onChange(of: isAdReady) {
            if isAdReady {
                print("✅ Ad is ready, hiding loading message")
                showLoadingMessage = false
            } else {
                print("⏳ Countdown to show loading message before ad is ready")
                DispatchQueue.main.asyncAfter(deadline: .now() + (adManager.cooldownTime - 15)) {
                    if !isAdReady {
                        print("🔔 Showing 'Loading ad...' message")
                        showLoadingMessage = true
                    }
                }
            }
        }
        .onChange(of: showAd) {
            print("🔄 showAd changed to: \(showAd)")
        }
        .overlay(
            RewardedInterstitialAdView(
                showAd: $showAd,
                isAdReady: $isAdReady,
                onRewardEarned: { amount, type in
                    print("🎉 Reward Earned: \(amount) \(type)")
                },
                adManager: adManager
            )
        )
    }

    private func resetAdState() {
        showLoadingMessage = false
        rotationAngle = 0
    }
}


//struct RewardedAdSection: View {
//    @Binding var showAd: Bool
//    @Binding var isAdReady: Bool
//    
//    @State private var elapsedTime: TimeInterval = 0  // ✅ Track time since launch
//    @State private var showLoadingMessage = false  // ✅ Controls when to show loading message
//    @State private var rotationAngle: Double = 0  // ✅ Rotation for hourglass animation
//    
//    var adManager: AdManager
//
//    var body: some View {
//        VStack {
//            if adManager.isAdReady {
//                Text("Task Beacon Rewards")
//                    .font(.title)
//                    .padding()
//
//                Button("Watch Ad for Extra To-Do") {
//                    if adManager.canShowAd() {
//                        print("🚀 Button Pressed: Setting showAd = true")
//                        DispatchQueue.main.async {
//                            showAd = true  // ✅ Manually trigger ad
//                        }
//                    } else {
//                        print("⏳ Ad is still in cooldown. Please wait...")
//                    }
//                }
//                .padding()
//                .background(Color.blue)
//                .foregroundColor(.white)
//                .cornerRadius(10)
//            } else if showLoadingMessage {
//                VStack {
//                    Image(systemName: "hourglass")
//                        .font(.system(size: 50))
//                        .rotationEffect(.degrees(rotationAngle))
//                        .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: rotationAngle)
//                        .onAppear {
//                            rotationAngle = 360  // ✅ Start rotation
//                        }
//
//                    Text("⏳ Loading ad...")
//                        .foregroundColor(.gray)
//                        .padding()
//                }
//            }
//        }
//        .onAppear {
//            print("⏳ Tracking ad availability...")
//            resetAdState()  // ✅ Ensure correct initial state
//        }
//        .onChange(of: isAdReady) {
//            if isAdReady {
//                print("✅ Ad is ready, hiding loading message")
//                showLoadingMessage = false  // ✅ Hide spinner & message when ad is ready
//            } else {
//                print("⏳ Starting countdown to show loading message before ad is ready")
//                DispatchQueue.main.asyncAfter(deadline: .now() + (adManager.cooldownTime - 15)) {
//                    if !isAdReady {  // ✅ Only show message if ad is still not ready
//                        print("🔔 Showing 'Loading ad...' message (15s before ad)")
//                        showLoadingMessage = true
//                    }
//                }
//            }
//        }
//        .onChange(of: showAd) {
//            print("🔄 showAd changed to: \(showAd)")
//        }
//        .overlay(
//            RewardedInterstitialAdView(
//                showAd: $showAd,
//                isAdReady: $isAdReady,
//                onRewardEarned: { amount, type in  // ✅ Closure now comes first
//                    print("🎉 Reward Earned: \(amount) \(type)")
//                },
//                adManager: adManager  // ✅ adManager now comes last
//            )
//        )
//    }
//    
//    private func resetAdState() {
//        showLoadingMessage = false
//        rotationAngle = 0
//    }
//}

//#Preview {
//    RewardedAdSection()
//}
