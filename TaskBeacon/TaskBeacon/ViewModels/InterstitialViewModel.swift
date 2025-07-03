//
//  InterstitialViewModel.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/14/25.
//

import Foundation
import GoogleMobileAds
import SwiftUI

class InterstitialViewModel: NSObject, ObservableObject, FullScreenContentDelegate {
    private var interstitialAd: InterstitialAd?
    private var onAdDismissed: (() -> Void)?
    private var onAdReady: (() -> Void)?
    private var onAdFailed: (() -> Void)?

    func loadAndShowAd(onDismissed: @escaping () -> Void,
                       onAdReady: @escaping () -> Void = {},
                       onAdFailed: @escaping () -> Void = {}
    ) {
        self.onAdDismissed = onDismissed
        self.onAdReady = onAdReady
        self.onAdFailed = onAdFailed

        let adUnitID = "ca-app-pub-7371576916843305/8036047270" // "ca-app-pub-3940256099942544/4411468910" // Test Ad Unit ID
        
                    // live ad unit id
//            interstitialAd = try await InterstitialAd.load(
//                        with: "ca-app-pub-7371576916843305/8036047270",
        
        print("�� Attempting to load interstitial ad with unit ID: \(adUnitID)")
        print("🔍 MobileAds.shared.isSDKInitialized: \(MobileAds.shared)")

        do {
            try InterstitialAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Failed to load interstitial ad: \(error.localizedDescription)")
                    print("🔍 Error details: \(error)")
                    self.onAdFailed?() // Call failure callback
                    self.onAdDismissed?() // Dismiss the sheet if loading fails
                    return
                }
                
                print("✅ Interstitial ad loaded successfully")

                self.interstitialAd = ad
                self.interstitialAd?.fullScreenContentDelegate = self
                
                self.onAdReady?()
                
                
                self.presentAd()
            }
        } catch {
            print("Failed to load interstitial ad with error: \(error.localizedDescription)")
            self.onAdFailed?() // Call failure callback
        }
    }
    
    private func presentAd() {
        guard let ad = self.interstitialAd else {
            print("Ad was not ready to present.")
            self.onAdFailed?()
            return
        }
        
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?
            .windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
            print("Could not find a root view controller to present the ad.")
            self.onAdFailed?()
            return
        }
        
        ad.present(from: rootViewController)
    }
    
    func showInterstitialAd() {
        guard let interstitialAd = interstitialAd else {
            return print("Interstitial ad wasn't ready.")
        }
        
        interstitialAd.present(from: nil)
    }
    
    // MARK: - GADFullScreenContentDelegate methods
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("💰 Interstitial ad impression recorded - Revenue event")
    }
    
    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        print("💰 Interstitial ad click recorded - Additional revenue event")
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Interstitial ad failed to present: \(error.localizedDescription)")
        self.onAdFailed?() // Dismiss the sheet on failure
        self.interstitialAd = nil
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Interstitial ad will present")
    }
    
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Interstitial ad will dismiss")
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Interstitial ad did dismiss")
        self.onAdDismissed?() // This is the crucial step to dismiss the sheet
        self.interstitialAd = nil
    }
}
