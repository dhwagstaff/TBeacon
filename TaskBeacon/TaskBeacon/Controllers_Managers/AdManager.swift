//
//  AdManager.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/5/25.
//

import Foundation

class AdManager: ObservableObject {
    @Published var isAdReady: Bool = false
    
    var lastAdTime: Date?  // ✅ Tracks last ad time
    let cooldownTime: TimeInterval = 120  // ⏳ 120-second cooldown
    
    func canShowAd() -> Bool {
        guard let lastAdTime = lastAdTime else {
            print("✅ No last ad time, allowing ad.")
            return true  // ✅ First ad is always allowed
        }

        let timeSinceLastAd = Date().timeIntervalSince(lastAdTime)
        let canShow = timeSinceLastAd >= cooldownTime  // ✅ Ensure `>=` instead of `>`

        print("⏳ Ad cooldown check: \(timeSinceLastAd) seconds since last ad. Can show? \(canShow)")
        return canShow
    }

    func showAd() {
        if canShowAd() {
            print("🚀 Showing Ad...")
            lastAdTime = Date()  // ✅ Update last ad time
            isAdReady = false  // ✅ Prevent immediate re-display
            loadNewAd()
        } else {
            print("⏳ Please wait before showing another ad")
        }
    }

    func loadNewAd() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { // Simulating Ad Load
            self.isAdReady = true
            print("✅ New ad is ready to be displayed")
        }
    }
}
