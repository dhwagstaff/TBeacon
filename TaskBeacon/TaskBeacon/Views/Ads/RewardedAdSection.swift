//
//  RewardedAdSection.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/5/25.
//

import SwiftUI

struct RewardedAdSection: View {
    @AppStorage("hasShownPersonalizationPrompt") private var hasShownPersonalizationPrompt = false
    @AppStorage("isPersonalizedAdsEnabled") private var isPersonalizedAdsEnabled = false

    @Binding var showAd: Bool
    @Binding var isAdReady: Bool
    @Binding var taskBeaconRewardsIsShowing: Bool
    
    @State private var showPersonalizationPrompt = false
    
    var adManager: AdManager

    var body: some View {
        VStack {
            Text("Task Beacon Rewards")
                .font(.title)
                .padding()
            
            Button(action: {
                if !hasShownPersonalizationPrompt {
                    showPersonalizationPrompt = true
                } else {
                    showAd = true
                }
            }) {
                Text("Watch Ad for Extra To-Do")
                 .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!adManager.canShowAd())
            .frame(maxWidth: .infinity)
            .padding([.leading, .trailing], 20)

            // Add cancel button below
            Button(action: {
                taskBeaconRewardsIsShowing = false
                showAd = false
                isAdReady = false
                adManager.cancelAd()
                print("❌ User cancelled ad, setting cancellation state")
            }) {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: .infinity)
            .padding([.leading, .trailing], 20)
        }
        .alert("Personalized Ads", isPresented: $showPersonalizationPrompt) {
            Button("Enable Personalized Ads") {
                adManager.updatePersonalizationPreference(isEnabled: true)
                hasShownPersonalizationPrompt = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("✅ Triggering personalized ad")
                    showAd = true
                    adManager.showAd()  // Explicitly call showAd
                    // Dismiss the sheet after selection
                    taskBeaconRewardsIsShowing = false
                }
            }
            
            Button("Continue with Non-Personalized Ads") {
                print("🔄 User chose non-personalized ads")
                adManager.updatePersonalizationPreference(isEnabled: false)
                hasShownPersonalizationPrompt = true
              //  showAd = true
                                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("✅ Triggering non-personalized ad")
                    showAd = true
                    adManager.showAd()  // Explicitly call showAd
                    // Dismiss the sheet after selection
                    
                    if adManager.isAdReady {
                        taskBeaconRewardsIsShowing = false
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                // Just dismiss the alert
                taskBeaconRewardsIsShowing = false
                showAd = false
                isAdReady = false
                adManager.cancelAd()
            }
        } message: {
            Text("Personalized ads help keep Task Beacon free. Would you like to enable personalized ads?")
        }
    }
}

//#Preview {
//    RewardedAdSection()
//}
