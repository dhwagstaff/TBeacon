//
//  ListsViewModel.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 5/15/25.
//

import Foundation
import MapKit
import SwiftUI

// Base class for common list functionality
class ListsViewModel: NSObject, ObservableObject {
    @AppStorage("preferredStoreName") private var preferredStoreName: String = ""
    @AppStorage("preferredStoreAddress") private var preferredStoreAddress: String = ""
    @AppStorage("preferredStoreLatitude") private var preferredStoreLatitude: Double = 0.0
    @AppStorage("preferredStoreLongitude") private var preferredStoreLongitude: Double = 0.0

    @Published var activeCategories: [String: [String]] = [:]
    @Published var errorMessage: String = Constants.emptyString
    @Published var showErrorAlert = false
    @Published var refreshTrigger = UUID()
    
    var entitlementManager: EntitlementManager = EntitlementManager.shared
    
    let isEditingExistingItem: Bool
    
    init(isEditingExistingItem: Bool = false) {
        self.isEditingExistingItem = isEditingExistingItem
        super.init()
    }
    
    func isPreferredStore(_ store: StoreOption) -> Bool {
        return !preferredStoreName.isEmpty &&
               store.name == preferredStoreName &&
               store.address == preferredStoreAddress
    }
    
    func isPreferredStore(_ mapItem: MKMapItem) -> Bool {
        let name = mapItem.name ?? ""
        let address = LocationManager.shared.getAddress(mapItem)
        return !preferredStoreName.isEmpty &&
               name == preferredStoreName &&
               address == preferredStoreAddress
    }
    
    func isOverFreeLimit(isEditingExistingItem: Bool = false) -> Bool {
        FreeLimitChecker.isOverFreeLimit(
            isPremiumUser: entitlementManager.isPremiumUser,
            isEditingExistingItem: isEditingExistingItem)
    }
    
    func tryShowInterstitialAdIfNeeded(isShowingRewardedAd: Bool) {
        if AppDelegate.shared.adManager.canShowInterstitialAd() && !isShowingRewardedAd {
            AppDelegate.shared.adManager.showInterstitialAd() // This should call the SDK's present method
            AppDelegate.shared.adManager.lastInterstitialAdTime = Date()
        }
    }
    
    // Common functions
    func removeCategory(subcategory: String, department: String, categoryIsForToDoItems: Bool) {
        DispatchQueue.main.async {
            // Remove the subcategory from activeCategories if empty
            if let index = self.activeCategories[department]?.firstIndex(of: subcategory) {
                self.activeCategories[department]?.remove(at: index)
            }
            
            // If no more subcategories exist for this department, remove it
            if self.activeCategories[department]?.isEmpty == true {
                self.activeCategories.removeValue(forKey: department)
            }
        }
    }
    
    func togglePreferredStore(isPreferredStore: Bool, store: StoreOption) {
        if isPreferredStore {
            // Clear preferred store
            preferredStoreName = ""
            preferredStoreAddress = ""
            preferredStoreLatitude = 0.0
            preferredStoreLongitude = 0.0
            print("🗑️ Cleared preferred store")
        } else {
            // Set this store as preferred store
            preferredStoreName = store.name
            preferredStoreAddress = store.address
            preferredStoreLatitude = store.mapItem.placemark.coordinate.latitude
            preferredStoreLongitude = store.mapItem.placemark.coordinate.longitude
            print("⭐ Set preferred store: \(store.name)")
        }
    }
}
