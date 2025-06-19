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
    private static let BASE_FREE_LIMIT = 50
    
    // Add a UserDefaults key for tracking rewarded items
    private static let REWARDED_ITEMS_KEY = "rewardedItemsCount"
    
    // Function to increment the rewarded items count
    static func incrementRewardedItems() {
        let currentCount = UserDefaults.standard.integer(forKey: REWARDED_ITEMS_KEY)
        UserDefaults.standard.set(currentCount + 1, forKey: REWARDED_ITEMS_KEY)
    }
    
    // Function to get the current total limit (base + rewarded)
    static func getCurrentLimit() -> Int {
        let rewardedCount = UserDefaults.standard.integer(forKey: REWARDED_ITEMS_KEY)
        return BASE_FREE_LIMIT + rewardedCount
    }
    
    static func isOverFreeLimit(isPremiumUser: Bool, isEditingExistingItem: Bool) -> Bool {
        guard !isPremiumUser else { return false }
        guard !isEditingExistingItem else { return false } // Allow editing existing items

        let context = PersistenceController.shared.container.viewContext
        let shoppingRequest = NSFetchRequest<ShoppingItemEntity>(entityName: CoreDataEntities.shoppingItem.stringValue)
        let todoRequest = NSFetchRequest<ToDoItemEntity>(entityName: CoreDataEntities.toDoItem.stringValue)

        do {
            let shoppingCount = try context.count(for: shoppingRequest)
            let todoCount = try context.count(for: todoRequest)
            let totalItems = shoppingCount + todoCount
            let currentLimit = getCurrentLimit()
            
            return totalItems >= currentLimit
        } catch {
            print("Error checking item limit: \(error.localizedDescription)")
            return true // Prevent creation if we can't verify the count
        }
    }
}

//struct FreeLimitChecker {
//    static func isOverFreeLimit(isPremiumUser: Bool, isEditingExistingItem: Bool) -> Bool {
//        guard !isPremiumUser else { return false }
//        guard !isEditingExistingItem else { return false } // Allow editing existing items
//
//        let context = PersistenceController.shared.container.viewContext
//        let shoppingRequest = NSFetchRequest<ShoppingItemEntity>(entityName: CoreDataEntities.shoppingItem.stringValue)
//        let todoRequest = NSFetchRequest<ToDoItemEntity>(entityName: CoreDataEntities.toDoItem.stringValue)
//
//        do {
//            let shoppingCount = try context.count(for: shoppingRequest)
//            let todoCount = try context.count(for: todoRequest)
//            return (shoppingCount + todoCount) >= 5
//        } catch {
//            print("Error checking item limit: \(error.localizedDescription)")
//            return true // Prevent creation if we can't verify the count
//        }
//    }
//}
