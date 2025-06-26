//
//  AdManager.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/5/25.
//

import Foundation
import GoogleMobileAds
import UserMessagingPlatform

class AdManager: ObservableObject {
    @Published var isAdReady: Bool = false
    @Published var canRequestAds: Bool = false
    @Published var isPrivacyOptionsRequired: Bool = false
    @Published var hasShownPersonalizationPrompt: Bool = false
    @Published var isPersonalizedAdsEnabled: Bool = false
    @Published var isCancelled: Bool = false
    @Published var isAdLoading = false
    @Published var isShowingRewardedAd: Bool = false

    private var isSDKInitialized: Bool = false
    private var rewardedInterstitialViewModel: RewardedInterstitialViewModel?
    
    var interstitialViewModel: InterstitialViewModel?

    var lastAdTime: Date?
    var lastInterstitialAdTime: Date?
    var entitlementManager: EntitlementManager?

    let cooldownTime: TimeInterval = 120
    let interstitialCooldownTime: TimeInterval = 180
    let minGapBetweenAds: TimeInterval = 120
        
    init() {
        // Load saved personalization preference
        hasShownPersonalizationPrompt = UserDefaults.standard.bool(forKey: "hasShownPersonalizationPrompt")
        isPersonalizedAdsEnabled = UserDefaults.standard.bool(forKey: "isPersonalizedAdsEnabled")
        
        self.interstitialViewModel = InterstitialViewModel()
        
        // Initialize consent status
        Task { @MainActor in
            await updateConsentStatus()
        }
    }
    
    @MainActor func updateConsentStatus() async {
        do {
            let consentInfo = ConsentInformation.shared
            print("📊 Current consent status - canRequestAds: \(consentInfo.canRequestAds)")
            
            if !consentInfo.canRequestAds {
                print("⏳ Waiting for consent to be gathered...")
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            canRequestAds = GoogleMobileAdsConsentManager.shared.canRequestAds
            isPrivacyOptionsRequired = GoogleMobileAdsConsentManager.shared.isPrivacyOptionsRequired
            
            print("📊 AdManager Consent Status Updated - canRequestAds: \(canRequestAds), isPrivacyOptionsRequired: \(isPrivacyOptionsRequired)")
            
            if canRequestAds {
                // Initialize SDK if not already initialized
                if !isSDKInitialized {
                    print("✅ Consent granted, initializing SDK...")
                    GoogleMobileAdsConsentManager.shared.startGoogleMobileAdsSDK()
                    isSDKInitialized = true
                }
                loadNewAd()
                loadInterstitialAd()
            }
        } catch {
            print("❌ Error updating consent status: \(error)")
        }
    }
    
    func canShowAd() -> Bool {
        if isCancelled {
            print("❌ Cannot show ad: Ad was cancelled")
            return false
        }
        let now = Date()
        let sinceLastRewarded = lastAdTime.map { now.timeIntervalSince($0) } ?? .infinity
        let sinceLastInterstitial = lastInterstitialAdTime.map { now.timeIntervalSince($0) } ?? .infinity
        let sinceAnyAd = min(sinceLastRewarded, sinceLastInterstitial)
        let canShow = sinceLastRewarded >= cooldownTime && sinceAnyAd >= minGapBetweenAds

        print("⏳ Rewarded ad cooldown check: \(sinceLastRewarded) seconds since last rewarded ad. Can show? \(canShow)")
        print("⏳ Min gap check: \(sinceAnyAd) seconds since any ad. Required: \(minGapBetweenAds)")
        return canShow
    }
    
    // Add a new method specifically for limit extension rewards
    func canShowLimitExtensionReward() -> Bool {
        if isCancelled {
            print("❌ Cannot show limit extension reward: Ad was cancelled")
            return false
        }
        
        // For limit extension rewards, we don't check cooldown
        // We only check if the ad is ready and not already showing
        return canRequestAds && !isShowingRewardedAd
    }
    
    func showInterstitialAd() {
        if canShowInterstitialAd() {
            print("🚀 Showing Interstitial Ad...")
            interstitialViewModel?.showInterstitialAd() // This should call the SDK's present method
            lastInterstitialAdTime = Date()
        } else {
            print("⏳ Please wait before showing another interstitial ad")
        }
    }

    func canShowInterstitialAd() -> Bool {
        print("🔍 AdManager.entitlementManager is nil? \(entitlementManager == nil)")

        if let em = entitlementManager {
            print("🔍 AdManager.entitlementManager.isPremiumUser: \(em.isPremiumUser)")
            print("🔍 AdManager.entitlementManager instance: \(em)")
        } else {
            print("🔍 AdManager.entitlementManager is nil!")
        }
        
        let isPremium = entitlementManager?.isPremiumUser ?? false
        print("🚫 AdManager checking premium status: \(isPremium)")
        
        if isPremium {
            print("🚫 Not showing interstitial ad - user is premium")
            return false
        }
        
        let isOverLimit = FreeLimitChecker.isOverFreeLimit(isPremiumUser: isPremium, isEditingExistingItem: false)
        if !isOverLimit {
            print("🚫 Not showing interstitial ad - user is not over free limit")
            return false
        }
        
        let now = Date()
        let sinceLastInterstitial = lastInterstitialAdTime.map { now.timeIntervalSince($0) } ?? .infinity
        let sinceLastRewarded = lastAdTime.map { now.timeIntervalSince($0) } ?? .infinity
        let sinceAnyAd = min(sinceLastRewarded, sinceLastInterstitial)
        let canShow = sinceLastInterstitial >= interstitialCooldownTime && sinceAnyAd >= minGapBetweenAds

        print("⏳ Interstitial ad cooldown check: \(sinceLastInterstitial) seconds since last interstitial ad. Can show? \(canShow)")
        print("⏳ Min gap check: \(sinceAnyAd) seconds since any ad. Required: \(minGapBetweenAds)")
        return canShow
    }
    
    // Add a new method to check if we can show the rewards section
    func canShowRewardsSection() -> Bool {
        return canRequestAds
    }

    func showAd() {
        if canShowAd() {
            print("🚀 Showing Ad...")
            if isAdReady {
                rewardedInterstitialViewModel?.showRewardedAd()
                lastAdTime = Date()
            } else {
                print("❌ Cannot show rewarded ad: Not ready yet")
            }
        } else {
            print("⏳ Please wait before showing another rewarded ad")
        }
    }

    func loadNewAd() {
        // Check if already loading
        if isAdLoading {
            print("⏳ Ad is already loading, skipping...")
            return
        }

        let isPremium = entitlementManager?.isPremiumUser ?? false
        if isPremium {
            print("🔹 Skipping rewarded ad load - user is premium")
            return
        }
        
        // Check consent before loading
        guard canRequestAds else {
            print("❌ Cannot load ad: No consent")
            isAdReady = false
            return
        }
        
        print("🔄 Loading new rewarded ad...")
        isAdLoading = true
        
        Task {
            await rewardedInterstitialViewModel?.loadAd()
        }
    }
    
    func loadInterstitialAd() {  // Add this
        let isPremium = entitlementManager?.isPremiumUser ?? false
        if isPremium {
            print("🔹 Skipping interstitial ad load - user is premium")
            return
        }
        
        let isInTrial = FreeLimitChecker.isInTrialPeriod()
        if isInTrial {
            print("🔹 Skipping interstitial ad load - user is in trial period")
            return
        }

        guard canRequestAds else {
            print("❌ Cannot load interstitial ad: No consent")
            return
        }
        
        print("🔄 Loading new interstitial ad...")
        
        Task {
            interstitialViewModel?.loadAndShowAd { }
        }
    }

    // Add a method to refresh entitlement status
    func refreshEntitlementStatus() {
        print("🔄 AdManager refreshing entitlement status...")
        if let em = entitlementManager {
            print("🔍 Current premium status: \(em.isPremiumUser)")
            
            if em.isPremiumUser {
                print("🔹 User is premium - disabling ads")
                isAdLoading = false
                isAdReady = false
                // Cancel any pending ad loads
            }
        } else {
            print("❌ No entitlement manager available")
        }
    }
}
