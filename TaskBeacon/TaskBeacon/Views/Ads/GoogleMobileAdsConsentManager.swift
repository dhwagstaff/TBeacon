//
//  Copyright 2023 Google LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import GoogleMobileAds
import UserMessagingPlatform

/// The Google Mobile Ads SDK provides the User Messaging Platform (Google's
/// IAB Certified consent management platform) as one solution to capture
/// consent for users in GDPR impacted countries. This is an example and
/// you can choose another consent management platform to capture consent.

@MainActor
class GoogleMobileAdsConsentManager: NSObject {
    static let shared = GoogleMobileAdsConsentManager()
    
    var isMobileAdsStartCalled = false
    
    var canRequestAds: Bool {
        return ConsentInformation.shared.canRequestAds
    }
    
    var isPrivacyOptionsRequired: Bool {
        return ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }
    
    /// Helper method to call the UMP SDK methods to request consent information and load/present a
    /// consent form if necessary.
    func gatherConsent(consentGatheringComplete: @escaping (Error?) -> Void) {
        let parameters = RequestParameters()
        
        // For testing purposes, you can use UMPDebugGeography to simulate a location.
        let debugSettings = DebugSettings()
        
        print("🔍 Starting consent gathering...")
        print("🔍 Publisher ID: ca-app-pub-7371576916843305~3348902851")
        print("�� Debug settings: \(debugSettings)")

        
     //   debugSettings.testDeviceIdentifiers = ["d848514766cb1b5f090f430b07efcc7d"]
        
        // live device id "6352B743-4C51-414E-98D1-30E98F63521E"
        
        // put this back in to have my device set as a test device
      //  debugSettings.testDeviceIdentifiers = ["d848514766cb1b5f090f430b07efcc7d"]
        debugSettings.geography = .EEA // Simulate being in the EEA to force consent form

        parameters.debugSettings = debugSettings
        
        // [START request_consent_info_update]
        // Requesting an update to consent information should be called on every app launch.
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] requestConsentError in
            
            guard let self = self else { return }
            
            // [START_EXCLUDE]
            guard requestConsentError == nil else {
                print("❌ Consent info update failed: \(String(describing: requestConsentError?.localizedDescription))")
                print("❌ Error details: \(String(describing: requestConsentError))")
                
                return consentGatheringComplete(requestConsentError)
            }
            
            print("✅ Consent info updated successfully")
            
            Task { @MainActor in
                do {
                    // [START load_and_present_consent_form]
                    try await ConsentForm.loadAndPresentIfRequired(from: nil)
                    // [END load_and_present_consent_form]
                    
                    self.startGoogleMobileAdsSDK()
                    
                    // Consent has been gathered.
                    consentGatheringComplete(nil)
                } catch {
                    print("❌ Error loading consent form: \(error.localizedDescription)")
                    print("❌ Error details: \(error)")
                    
                    consentGatheringComplete(error)
                }
            }
        }
    }
    
    /// Helper method to call the UMP SDK method to present the privacy options form.
    @MainActor func presentPrivacyOptionsForm() async throws {
        print("🔍 presentPrivacyOptionsForm called")
        
        // First, request consent info update
        let parameters = RequestParameters()
        let debugSettings = DebugSettings()
        
        // Add your device as test device (remove this for production)
        debugSettings.testDeviceIdentifiers = ["d848514766cb1b5f090f430b07efcc7d"]
        
        // TEMPORARY: Force consent form for testing (remove for production)
        debugSettings.geography = .EEA  // This will force the consent form to show
        
        parameters.debugSettings = debugSettings
        
        // Request consent info update first
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error = error {
                    print("❌ Consent info update failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ Consent info updated successfully")
                    continuation.resume()
                }
            }
        }
        
        // Now present the privacy options form
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
            print("✅ Privacy options form presented successfully")
        } catch {
            print("❌ Error presenting privacy options form: \(error.localizedDescription)")
            throw error
        }
    }
    
//    @MainActor func presentPrivacyOptionsForm() async throws {
//        do {
//            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
//        } catch {
//            print("❌ Error presenting privacy options form: \(error.localizedDescription)")
//            throw error
//        }
//    }
    
    /// Method to initialize the Google Mobile Ads SDK. The SDK should only be initialized once.
    func startGoogleMobileAdsSDK() {
        guard canRequestAds, !isMobileAdsStartCalled else {             print("🔍 SDK start conditions - canRequestAds: \(canRequestAds), isMobileAdsStartCalled: \(isMobileAdsStartCalled)")
 return }
        
        isMobileAdsStartCalled = true
        print("🚀 Starting Google Mobile Ads SDK...")
        
        // Initialize the Google Mobile Ads SDK.
        MobileAds.shared.start { status in
            print("✅ Google Mobile Ads SDK initialized with status: \(status)")
        }
    }
}
