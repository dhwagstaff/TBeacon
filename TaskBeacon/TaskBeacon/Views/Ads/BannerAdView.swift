//
//  BannerAdView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/4/25.
//

import SwiftUI
import GoogleMobileAds
import UIKit

struct BannerAdView: UIViewRepresentable {
    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("✅ Banner ad loaded successfully")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("❌ Failed to load banner ad: \(error.localizedDescription)")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    //  private let adUnitID = "ca-app-pub-7371576916843305/1060579034"

    private let testBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"

    func makeUIView(context: Context) -> UIView {
        print("🟦 Initializing BannerAdView...")

        let container = UIView()
        container.backgroundColor = .systemBackground

        guard let rootVC = getRootViewController() else {
            print("❌ Failed to get root view controller")
            return container
        }

        let bannerView = BannerView(adSize: AdSizeMediumRectangle)
        bannerView.adUnitID = testBannerAdUnitID
        bannerView.rootViewController = rootVC
        bannerView.delegate = context.coordinator
        
        // Add loading state handling
        bannerView.load(Request())

        bannerView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bannerView)

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            bannerView.widthAnchor.constraint(equalToConstant: 300),  // Standard medium rectangle width
            bannerView.heightAnchor.constraint(equalToConstant: 250)  // Standard medium rectangle height
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            print("❌ Failed to get root view controller")
            return nil
        }
        return rootVC
    }
}
