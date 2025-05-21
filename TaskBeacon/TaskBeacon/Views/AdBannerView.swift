//
//  AdBannerView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/4/25.
//

import SwiftUI

struct AdBannerView: View {
    @EnvironmentObject var subscriptionsManager: SubscriptionsManager

    var body: some View {
        if !subscriptionsManager.hasRemovedAds {
            VStack(spacing: 0) {
                BannerAdView() // ✅ Use actual ad view
                    .frame(height: 250) // Match AdSizeMediumRectangle
                    .background(Color(.systemBackground)) // ✅ Adapts to dark/light mode
                    .clipShape(RoundedRectangle(cornerRadius: 0))
            }
            .frame(maxWidth: .infinity)
            .transition(.opacity)
        }
    }
}

//struct AdBannerView: View {
//    @EnvironmentObject var subscriptionsManager: SubscriptionsManager
//    
//    var body: some View {
//        if !subscriptionsManager.hasRemovedAds {
//            // Show Ad
//            Text("Ad Placeholder") // Replace with real Ad view
//                .frame(maxWidth: .infinity, maxHeight: 50)
//                .background(Color.gray.opacity(0.3))
//        }
//    }
//}

#Preview {
    AdBannerView()
}
