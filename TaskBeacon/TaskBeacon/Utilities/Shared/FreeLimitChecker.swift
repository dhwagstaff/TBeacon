//
//  FreeLimitChecker.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 5/22/25.
//

import CoreData
import Foundation

struct FreeLimitChecker {
    // Add a constant for the base free limit
    private static let BASE_FREE_LIMIT = 5  // Regular free limit
    private static let TRIAL_LIMIT =  50
    private static let TRIAL_DURATION_KEY = "trial_start_date"
    private static let TRIAL_DURATION: TimeInterval = 7 * 24 * 60 * 60  // 7 days in seconds
    
    // Add a UserDefaults key for tracking rewarded items
    private static let REWARDED_ITEMS_KEY = "rewardedItemsCount"
    
    private static let DEBUG_TRIAL_LIMIT_KEY = "debug_trial_limit"
    private static let DEBUG_FREE_LIMIT_KEY = "debug_free_limit"

    // Keychain constants
    /*private*/ static let KEYCHAIN_SERVICE = "com.pocketmeapps.taskbeacon"
    /*private*/ static let KEYCHAIN_FIRST_LAUNCH_KEY = "first_launch_date"
    
    // Helper function to get the effective trial limit (with debug override)
    private static func getEffectiveTrialLimit() -> Int {
        let debugLimit = UserDefaults.standard.integer(forKey: DEBUG_TRIAL_LIMIT_KEY)
        return debugLimit > 0 ? debugLimit : TRIAL_LIMIT
    }
    
    // Helper function to get the effective base free limit (with debug override)
    private static func getEffectiveBaseFreeLimit() -> Int {
        let debugLimit = UserDefaults.standard.integer(forKey: DEBUG_FREE_LIMIT_KEY)
        return debugLimit > 0 ? debugLimit : BASE_FREE_LIMIT
    }
    
    // Get the first launch date from Keychain
    private static func getFirstLaunchDate() -> Date? {
        if let data = KeychainHelper.shared.read(service: KEYCHAIN_SERVICE, account: KEYCHAIN_FIRST_LAUNCH_KEY) {
            return try? JSONDecoder().decode(Date.self, from: data)
        }
        return nil
    }
    
    // Save the first launch date to Keychain
    private static func saveFirstLaunchDate() {
        let now = Date()
        if let data = try? JSONEncoder().encode(now) {
            KeychainHelper.shared.save(data, service: KEYCHAIN_SERVICE, account: KEYCHAIN_FIRST_LAUNCH_KEY)
        }
    }
    
    // Check if we're still in the trial period
    
    // Update the isInTrialPeriod function to be consistent
    static func isInTrialPeriod() -> Bool {
        if let firstLaunch = getFirstLaunchDate() {
            let currentDate = Date()
            let elapsed = currentDate.timeIntervalSince(firstLaunch)
            return elapsed < TRIAL_DURATION
        } else {
            // No first launch date saved, this is the first launch
            let currentDate = Date()
            saveFirstLaunchDate()
            return true
        }
    }

    // Add a function to reset trial for testing
    static func resetTrialForTesting() {
        KeychainHelper.shared.delete(service: KEYCHAIN_SERVICE, account: KEYCHAIN_FIRST_LAUNCH_KEY)
        print("🔹 Trial reset for testing")
    }
    
    // Function to increment the rewarded items count
    static func incrementRewardedItems() {
        let currentCount = UserDefaults.standard.integer(forKey: REWARDED_ITEMS_KEY)
        UserDefaults.standard.set(currentCount + 1, forKey: REWARDED_ITEMS_KEY)
    }
    
    // Function to get the current total limit (base + rewarded + trial bonus)
    static func getCurrentLimit() -> Int {
        let rewardedCount = UserDefaults.standard.integer(forKey: REWARDED_ITEMS_KEY)
        let baseLimit = isInTrialPeriod() ? getEffectiveTrialLimit() : getEffectiveBaseFreeLimit()
        return baseLimit + rewardedCount
    }
    
    // Get remaining trial days (nil if trial is over)
    static func getRemainingTrialDays() -> Int? {
        guard let firstLaunch = getFirstLaunchDate() else {
            return nil
        }
        
        let elapsed = Date().timeIntervalSince(firstLaunch)
        let remaining = TRIAL_DURATION - elapsed // 14 days in seconds
        
        if remaining <= 0 {
            return nil
        }
        
        return Int(ceil(remaining / (24 * 60 * 60)))
    }
    
    static func isOverFreeLimit(isPremiumUser: Bool, isEditingExistingItem: Bool) -> Bool {
        guard !isPremiumUser else {
            print("🔹 User is premium - not over limit")
            return false
        }
        guard !isEditingExistingItem else {
            print("🔹 Editing existing item - not over limit")
            return false
        } // Allow editing existing items

        let context = PersistenceController.shared.container.viewContext
        let shoppingRequest = NSFetchRequest<ShoppingItemEntity>(entityName: CoreDataEntities.shoppingItem.stringValue)
        let todoRequest = NSFetchRequest<ToDoItemEntity>(entityName: CoreDataEntities.toDoItem.stringValue)

        do {
            let shoppingCount = try context.count(for: shoppingRequest)
            let todoCount = try context.count(for: todoRequest)
            let totalItems = shoppingCount + todoCount
            let currentLimit = getCurrentLimit()
            
            print("�� Free limit check - Shopping items: \(shoppingCount)")
            print("�� Free limit check - ToDo items: \(todoCount)")
            print("�� Free limit check - Total items: \(totalItems)")
            print("�� Free limit check - Current limit: \(currentLimit)")
            print("�� Free limit check - Is over limit: \(totalItems >= currentLimit)")

            return totalItems >= currentLimit
        } catch {
            ErrorAlertManager.shared.showDataError("Error checking item limit: \(error.localizedDescription)")

            print("Error checking item limit: \(error.localizedDescription)")
            return true // Prevent creation if we can't verify the count
        }
    }
}
