//
//  RewardedInterstitialAdView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/5/25.
//

import GoogleMobileAds
import SwiftUI

struct RewardedInterstitialAdView: UIViewControllerRepresentable {
    @Binding var showAd: Bool
    @Binding var isAdReady: Bool  // ✅ Now tracking readiness from ContentView
    
    var onRewardEarned: (NSDecimalNumber, String) -> Void
    
    var adManager: AdManager  // ✅ Pass AdManager instance

    class Coordinator: NSObject, FullScreenContentDelegate {
        var parent: RewardedInterstitialAdView
        private var rewardedInterstitialAd: RewardedInterstitialAd?

        init(parent: RewardedInterstitialAdView) {
            self.parent = parent
            super.init()
            self.loadRewardedInterstitialAd()
        }

        func loadRewardedInterstitialAd() {
            print("⏳ Requesting a new Rewarded Ad...")
            
            let request = Request()
            RewardedInterstitialAd.load(
                with: "ca-app-pub-3940256099942544/5354046379", // ✅ Test Ad Unit ID
                request: request,
                completionHandler: { (ad, error) in
                    if let error = error {
                        print("❌ Failed to load new ad: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.parent.isAdReady = false
                        }
                        return
                    }
                    
                    self.rewardedInterstitialAd = ad
                    print("✅ New Rewarded Ad is READY!")

                    // ✅ Ensure SwiftUI gets updated
                    DispatchQueue.main.async {
                        self.parent.isAdReady = true
                    }
                })
        }

        func showRewardedInterstitialAd() {
            guard let ad = rewardedInterstitialAd else {
                print("❌ Ad wasn't ready when requested.")
                DispatchQueue.main.async {
                    self.parent.showAd = false  // ✅ Prevent ad loop
                }
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {  // ⏳ Small delay before showing ad
                if let rootVC = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                    .first {
                    print("🚀 Presenting Ad Now...")
                    ad.present(from: rootVC) {
                        let reward = ad.adReward
                        print("🎉 User earned reward: \(reward.amount) \(reward.type)")
                        self.parent.onRewardEarned(reward.amount, reward.type)

                        // ✅ Delay before reloading the ad
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.adDidDismiss()
                        }
                    }
                } else {
                    print("❌ Failed to find root view controller")
                }
            }
        }
        
        // ✅ Simulating `adDidDismissFullScreenContent`
        func adDidDismiss() {
            print("🛑 Ad dismissed. Setting cooldown before loading the next ad...")

            DispatchQueue.main.async {
                self.parent.isAdReady = false
                self.parent.showAd = false
                self.parent.adManager.lastAdTime = Date()  // ✅ Track last ad time
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + self.parent.adManager.cooldownTime) {
                print("🔄 Cooldown ended, attempting to load a new ad...")
                self.loadRewardedInterstitialAd()  // ✅ Reload after a short delay
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        print("🔄 Checking ad state: showAd=\(showAd), isAdReady=\(isAdReady)")

        if showAd && isAdReady && adManager.canShowAd() {
            print("🚀 Showing Ad...")
            DispatchQueue.main.async {
                context.coordinator.showRewardedInterstitialAd()
                self.showAd = false  // ✅ Reset trigger after displaying ad
            }
        } else {
            print("⏳ Ad cooldown active or not ready")
        }
    }
}

