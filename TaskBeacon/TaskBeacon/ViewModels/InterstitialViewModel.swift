//
//  InterstitialViewModel.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/14/25.
//

import Foundation
import GoogleMobileAds

class InterstitialViewModel: NSObject, ObservableObject, FullScreenContentDelegate {
    private var interstitialAd: InterstitialAd?

    func loadAd() async {
        do {
            // test ad unit id
            interstitialAd = try await InterstitialAd.load(
                with: "ca-app-pub-3940256099942544/4411468910",

            // live ad unit id
//            interstitialAd = try await InterstitialAd.load(
//                with: "ca-app-pub-7371576916843305/8036047270",
                request: Request()
            )
            interstitialAd?.fullScreenContentDelegate = self
        } catch {
            print("Failed to load interstitial ad with error: \(error.localizedDescription)")
        }
    }

    func showInterstitialAd() {
        guard let interstitialAd = interstitialAd else {
            return print("Interstitial ad wasn't ready.")
        }

        interstitialAd.present(from: nil)
    }

    // MARK: - GADFullScreenContentDelegate methods
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("Interstitial ad impression recorded")
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        print("Interstitial ad click recorded")
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Interstitial ad failed to present: \(error.localizedDescription)")
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Interstitial ad will present")
    }

    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Interstitial ad will dismiss")
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Interstitial ad did dismiss")
        interstitialAd = nil
    }
}
