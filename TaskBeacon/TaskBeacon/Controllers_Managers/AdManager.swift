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

    var lastAdTime: Date?
    let cooldownTime: TimeInterval = 120
    let cancellationCooldown: TimeInterval = 300
    
    init() {
        // Load saved personalization preference
        hasShownPersonalizationPrompt = UserDefaults.standard.bool(forKey: "hasShownPersonalizationPrompt")
        isPersonalizedAdsEnabled = UserDefaults.standard.bool(forKey: "isPersonalizedAdsEnabled")
        
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
                loadNewAd()
            }
        } catch {
            print("❌ Error updating consent status: \(error)")
        }
    }
    
    func canShowAd() -> Bool {
        // First check if ad was cancelled
        if isCancelled {
            print("❌ Cannot show ad: Ad was cancelled")
            return false
        }
        
        // Then check cooldown
        guard let lastAdTime = lastAdTime else {
            print("✅ No last ad time, allowing ad.")
            return true
        }

        let timeSinceLastAd = Date().timeIntervalSince(lastAdTime)
        let canShow = timeSinceLastAd >= cooldownTime

        print("⏳ Ad cooldown check: \(timeSinceLastAd) seconds since last ad. Can show? \(canShow)")
        return canShow
    }
    
    func cancelAd() {
        isCancelled = true
        isAdReady = false
        
        // Reset cancellation after 24 hours
        DispatchQueue.main.asyncAfter(deadline: .now() + cancellationCooldown) {
            self.isCancelled = false
        }
    }
    
    // Add a new method to check if we can show the rewards section
    func canShowRewardsSection() -> Bool {
        return canRequestAds
    }

    func showAd() {
        if canShowAd() {
            print("🚀 Showing Ad...")
            lastAdTime = Date()
            isAdReady = false
            loadNewAd()
        } else {
            print("⏳ Please wait before showing another ad")
        }
    }

    func loadNewAd() {
        // Check consent before loading
        guard canRequestAds else {
            print("❌ Cannot load ad: No consent")
            isAdReady = false
            return
        }
        
        print("🔄 Loading new ad...")
        
        // Load appropriate ad type based on personalization setting
        if isPersonalizedAdsEnabled {
            loadPersonalizedAd()
        } else {
            loadNonPersonalizedAd()
        }
    }
    
    private func loadPersonalizedAd() {
        // Load personalized ad
        print("🔄 Loading personalized ad...")
        DispatchQueue.main.async {
            self.isAdReady = true
            print("✅ New personalized ad is ready to be displayed")
        }
    }
    
    private func loadNonPersonalizedAd() {
        // Load non-personalized ad
        print("🔄 Loading non-personalized ad...")
        DispatchQueue.main.async {
            self.isAdReady = true
            print("✅ New non-personalized ad is ready to be displayed")
        }
    }
    
    func updatePersonalizationPreference(isEnabled: Bool) {
        print("🔄 Updating personalization preference: \(isEnabled)")

        isPersonalizedAdsEnabled = isEnabled
        hasShownPersonalizationPrompt = true
        isCancelled = false  // Reset cancellation state when user makes a choice

        // Save to UserDefaults
        UserDefaults.standard.set(isEnabled, forKey: "isPersonalizedAdsEnabled")
        UserDefaults.standard.set(true, forKey: "hasShownPersonalizationPrompt")
        
        print("🔐 \(isEnabled ? "Personalized" : "Non-personalized") ads enabled")
        
        // Generate a unique identifier for personalized ads
        if isEnabled {
            let userIdentifier = UUID().uuidString
            UserDefaults.standard.set(userIdentifier, forKey: "userIdentifier")
            print("🔐 Personalized ads enabled for user: \(userIdentifier)")
        } else {
            UserDefaults.standard.removeObject(forKey: "userIdentifier")
            print("🔐 Non-personalized ads enabled")
        }
        
        // Update Google's consent status
        Task { @MainActor in
            if let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first {
                try? await GoogleMobileAdsConsentManager.shared.presentPrivacyOptionsForm(from: rootVC)
            }
        }
        
        // Reload ad with new personalization setting
        print("🔄 Loading new ad with personalization setting: \(isEnabled)")
        loadNewAd()
    }
    
    func handleConsentUpdate() {
        Task { @MainActor in
            await updateConsentStatus()
        }

        if canRequestAds {
            loadNewAd()
        }
    }
}

//class AdManager: ObservableObject {
//    @Published var isAdReady: Bool = false
//    @Published var canRequestAds: Bool = false
//    @Published var isPrivacyOptionsRequired: Bool = false
//    
//    var lastAdTime: Date?
//    let cooldownTime: TimeInterval = 120
//    
//    init() {
//        // Initialize consent status
//        Task { @MainActor in
//            await updateConsentStatus()
//        }
//    }
//    
//    @MainActor func updateConsentStatus() async {
//        // Wait for consent to be gathered
//        do {
//            // First check if consent has been gathered
//            let consentInfo = ConsentInformation.shared
//            print("📊 Current consent status - canRequestAds: \(consentInfo.canRequestAds)")
//            
//            // If consent hasn't been gathered, wait for it
//            if !consentInfo.canRequestAds {
//                print("⏳ Waiting for consent to be gathered...")
//                // Wait for a short time to allow consent gathering to complete
//                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
//            }
//            
//            // Update our state with the latest consent status
//            canRequestAds = GoogleMobileAdsConsentManager.shared.canRequestAds
//            isPrivacyOptionsRequired = GoogleMobileAdsConsentManager.shared.isPrivacyOptionsRequired
//            
//            print("📊 AdManager Consent Status Updated - canRequestAds: \(canRequestAds), isPrivacyOptionsRequired: \(isPrivacyOptionsRequired)")
//            
//            // If we can request ads, try to load a new ad
//            if canRequestAds {
//                loadNewAd()
//            }
//        } catch {
//            print("❌ Error updating consent status: \(error)")
//        }
//    }
//    
//    func canShowAd() -> Bool {
//        // First check consent status
//        guard canRequestAds else {
//            print("❌ Cannot show ad: No consent")
//            return false
//        }
//        
//        // Then check cooldown
//        guard let lastAdTime = lastAdTime else {
//            print("✅ No last ad time, allowing ad.")
//            return true
//        }
//
//        let timeSinceLastAd = Date().timeIntervalSince(lastAdTime)
//        let canShow = timeSinceLastAd >= cooldownTime
//
//        print("⏳ Ad cooldown check: \(timeSinceLastAd) seconds since last ad. Can show? \(canShow)")
//        return canShow
//    }
//
//    func showAd() {
//        if canShowAd() {
//            print("🚀 Showing Ad...")
//            lastAdTime = Date()
//            isAdReady = false
//            loadNewAd()
//        } else {
//            print("⏳ Please wait before showing another ad")
//        }
//    }
//
//    func loadNewAd() {
//        // Check consent before loading
//        guard canRequestAds else {
//            print("❌ Cannot load ad: No consent")
//            isAdReady = false
//            return
//        }
//        
//        print("🔄 Loading new ad...")
//        
//        DispatchQueue.main.async {
//            self.isAdReady = true
//            print("✅ New ad is ready to be displayed")
//        }
//    }
//    
////    func loadNewAd() {
////        // Check consent before loading
////        guard canProceedWithAd() else {
////            print("❌ Cannot load ad: No consent")
////            isAdReady = false
////            return
////        }
////        
////        print("🔄 Loading new ad...")
////        
////        DispatchQueue.main.async {
////            self.isAdReady = true
////            print("✅ New ad is ready to be displayed")
////        }
////    }
//    
//    func canProceedWithAd() -> Bool {
//        // Update consent status
////        Task { @MainActor in
////            await updateConsentStatus()
////        }
//        
//        // Check both consent and premium status
////        guard canRequestAds else {
////            print("❌ Cannot proceed: No consent")
////            return false
////        }
//        
//        return canRequestAds
//    }
//    
//    // Add method to handle consent changes
//    func handleConsentUpdate() {
//        Task { @MainActor in
//            await updateConsentStatus()
//        }
//
//        if canRequestAds {
//            loadNewAd()
//        }
//    }
//}
