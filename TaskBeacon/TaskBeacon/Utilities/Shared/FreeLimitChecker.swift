//
//  FreeLimitChecker.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 5/22/25.
//

import CoreData
import Foundation

struct FreeLimitChecker {
    static func isOverFreeLimit(isPremiumUser: Bool, isEditingExistingItem: Bool) -> Bool {
        guard !isPremiumUser else { return false }
        guard !isEditingExistingItem else { return false } // Allow editing existing items

        let context = PersistenceController.shared.container.viewContext
        let shoppingRequest = NSFetchRequest<ShoppingItemEntity>(entityName: CoreDataEntities.shoppingItem.stringValue)
        let todoRequest = NSFetchRequest<ToDoItemEntity>(entityName: CoreDataEntities.toDoItem.stringValue)

        do {
            let shoppingCount = try context.count(for: shoppingRequest)
            let todoCount = try context.count(for: todoRequest)
            return (shoppingCount + todoCount) >= 5
        } catch {
            print("Error checking item limit: \(error.localizedDescription)")
            return true // Prevent creation if we can't verify the count
        }
    }
}
