//
//  ListsViewModel.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 5/15/25.
//

import Foundation

// Base class for common list functionality
class ListsViewModel: NSObject, ObservableObject {
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
}
