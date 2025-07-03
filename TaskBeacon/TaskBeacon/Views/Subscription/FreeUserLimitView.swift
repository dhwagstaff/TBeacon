//
//  FreeUserLimitView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 4/30/25.
//

import SwiftUI

struct FreeUserLimitView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var adManager: AdManager

    @Binding var showSubscriptionSheet: Bool
    @Binding var showRewardedAd: Bool
        
    var body: some View {
        RoundedSectionBackground(
            backgroundColor: colorScheme == .dark ?
                Color(.systemGray6) :
                Color(.systemBackground),
            title: "Free Version Limit",
            iconName: "exclamationmark.triangle.fill"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let remainingDays = FreeLimitChecker.getRemainingTrialDays() {
                    // Trial Period Active
                    Text("🎉 Trial Period: \(remainingDays) days remaining")
                        .foregroundColor(.green)
                        .font(.subheadline)
                    
                    Text("You can add up to \(FreeLimitChecker.getCurrentLimit()) items during your trial!")
                        .foregroundColor(.primary)
                        .font(.subheadline)
                    
                    Text("After trial ends, limit reduces to 5 items unless upgraded to Premium.")
                        .font(.footnote)
                        .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                } else {
                    // Trial Period Ended
                    Text("⏰ Your 1-week trial has expired")
                        .foregroundColor(.orange)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.top, 8)

                    Text("🚫 Free users can only add up to 5 items total (shopping and to-do items combined).")
                        .foregroundColor(.red)
                        .font(.subheadline)
                    
                    Text("Upgrade to Premium for unlimited items and no ads!")
                        .font(.footnote)
                        .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                }
                
                Text("Choose an option to continue:")
                    .font(.footnote)
                    .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                    .padding(.top, 4)
                
                // Watch Ad Button
                Button(action: {
                    showRewardedAd = true
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Watch Ad for Extra Item")
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        colorScheme == .dark ?
                            Color(hex: "1240AB").opacity(0.8) :
                            Color(hex: "1240AB")
                    )
                    .cornerRadius(8)
                }
                .padding(.top, 8)
                
                // Premium Upgrade Button
                Button(action: {
                    showSubscriptionSheet = true
                }) {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Upgrade to Premium")
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        colorScheme == .dark ?
                            Color.accentColor.opacity(0.8) :
                            Color.accentColor
                    )
                    .cornerRadius(8)
                }
                
                Text("Premium users get unlimited items and more features!")
                    .font(.footnote)
                    .foregroundColor(colorScheme == .dark ? .gray : .secondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal)
        }
    }
}

//#Preview {
//    FreeUserLimitView()
//}
