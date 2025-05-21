//
//  PersistenceController.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/5/25.
//

import CoreData
import Foundation

// MARK: - PersistenceController
class PersistenceController {
    static let shared = PersistenceController()
    
    // Add a preview instance for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TaskBeacon")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Unresolved error \(error)")
            }
        }
    }
    
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving Core Data: \(error)")
            }
        }
    }
    
    // In PersistenceController.swift
    func canAddMoreItems(context: NSManagedObjectContext) -> Bool {
        let shoppingRequest = NSFetchRequest<ShoppingItemEntity>(entityName: CoreDataEntities.shoppingItem.stringValue)
        let todoRequest = NSFetchRequest<ToDoItemEntity>(entityName: CoreDataEntities.toDoItem.stringValue)
        
        do {
            let shoppingCount = try context.count(for: shoppingRequest)
            let todoCount = try context.count(for: todoRequest)
            return (shoppingCount + todoCount) < 5 // Combined limit of 5 items
        } catch {
            print("Error fetching item count: \(error.localizedDescription)")
            return false
        }
    }
}
