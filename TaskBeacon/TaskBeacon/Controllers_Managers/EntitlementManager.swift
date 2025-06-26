//
//  EntitlementManager.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/1/25.
//

import SwiftUI

class EntitlementManager: ObservableObject {
    @AppStorage("extraToDoOrShoppingItems", store: userDefaults) var extraToDoSlots: Int = 0
    @AppStorage("isAdFree", store: userDefaults) var isAdFree: Bool = false
    @AppStorage("hasChosenFreeVersion", store: userDefaults) var hasChosenFreeVersion: Bool = false
    
    @Published var subscriptionsManager: SubscriptionsManager?
    @Published var hasMonthlySubscription: Bool = false
    @Published var hasAnnualSubscription: Bool = false

    static let userDefaults = UserDefaults(suiteName: "group.pocketmeapps.taskbeacon")!
    
    static let shared = EntitlementManager()

    @Published var isPremiumUser: Bool {
        didSet {
            Self.userDefaults.set(isPremiumUser, forKey: "isPremiumUser")
            Self.userDefaults.synchronize() // Force immediate save
            objectWillChange.send() // 🔹 Ensure UI refresh
            print("🔹 EntitlementManager: isPremiumUser changed to \(isPremiumUser)")
        }
    }

    init() {
        // Load value from UserDefaults at startup
        isPremiumUser = Self.userDefaults.bool(forKey: "isPremiumUser")
        hasMonthlySubscription = Self.userDefaults.bool(forKey: "hasMonthlySubscription")
        hasAnnualSubscription = Self.userDefaults.bool(forKey: "hasAnnualSubscription")
        
        print("🔹 EntitlementManager initialized - isPremiumUser: \(isPremiumUser), hasMonthly: \(hasMonthlySubscription), hasAnnual: \(hasAnnualSubscription)")
        print("🔹 UserDefaults values - isPremiumUser: \(Self.userDefaults.bool(forKey: "isPremiumUser")), hasMonthly: \(Self.userDefaults.bool(forKey: "hasMonthlySubscription")), hasAnnual: \(Self.userDefaults.bool(forKey: "hasAnnualSubscription"))")
    }
    
    func checkSubscriptionStatus() {
        // Check if subscriptionsManager is available
        guard let subscriptionsManager = subscriptionsManager else {
            print("❌ SubscriptionsManager not available for status check")
            return
        }
        
        // Use SubscriptionsManager's current state
        Task { @MainActor in
            let hasMonthly = subscriptionsManager.purchasedProductIDs.contains("PMA_TBPM_25")
            let hasAnnual = subscriptionsManager.purchasedProductIDs.contains("PMA_TBPA_25")
            
            hasMonthlySubscription = hasMonthly
            hasAnnualSubscription = hasAnnual
            isPremiumUser = hasMonthly || hasAnnual
            
            // Persist the values
            Self.userDefaults.set(hasMonthlySubscription, forKey: "hasMonthlySubscription")
            Self.userDefaults.set(hasAnnualSubscription, forKey: "hasAnnualSubscription")
            Self.userDefaults.set(isPremiumUser, forKey: "isPremiumUser")
            
            print("🔹 Subscription status updated - isPremiumUser: \(isPremiumUser), hasMonthly: \(hasMonthlySubscription), hasAnnual: \(hasAnnualSubscription)")
        }
    }

    func updateSubscriptionStatus(isPremium: Bool, hasMonthly: Bool, hasAnnual: Bool) {
        DispatchQueue.main.async {
            self.isPremiumUser = isPremium
            self.hasMonthlySubscription = hasMonthly
            self.hasAnnualSubscription = hasAnnual
            
            // Persist the values
            Self.userDefaults.set(hasMonthly, forKey: "hasMonthlySubscription")
            Self.userDefaults.set(hasAnnual, forKey: "hasAnnualSubscription")
            Self.userDefaults.set(isPremium, forKey: "isPremiumUser")
            Self.userDefaults.synchronize() // Force immediate save
            
            print("🔹 About to call AdManager refresh...")
            
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.adManager.refreshEntitlementStatus()
                print("🔹 AdManager entitlement status refreshed")
            }
            
            print("🔹 EntitlementManager subscription status updated - isPremiumUser: \(isPremium), hasMonthly: \(hasMonthly), hasAnnual: \(hasAnnual)")
            print("🔹 UserDefaults synchronized")
        }
    }
    
    func forceRefreshSubscriptionStatus() {
        print("🔄 Force refreshing subscription status...")
        checkSubscriptionStatus()
    }
    
    func getCurrentStatus() -> (isPremium: Bool, hasMonthly: Bool, hasAnnual: Bool) {
        return (isPremiumUser, hasMonthlySubscription, hasAnnualSubscription)
    }
}
