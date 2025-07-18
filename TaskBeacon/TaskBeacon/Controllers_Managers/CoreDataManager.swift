//
//  CoreDataManager.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 4/1/25.
//

import CoreData
import Foundation

enum CoreDataEntities: String {
    case shoppingItem
    case toDoItem
    
    var stringValue: String {
        switch self {
        case .shoppingItem:
            return "ShoppingItemEntity"
        case .toDoItem:
            return "ToDoItemEntity"
        }
    }
}

protocol CoreDataManagerProtocol {
    // Fetches objects from Core Data based on the provided entity name, predicate, and sorting criteria.
    func fetch<T: NSManagedObject>(entityName: String, with predicate: NSPredicate?, sortBy key: String?) async throws -> [T]
    
    // Updates an existing object in Core Data.
    func updateObject<T: NSManagedObject>(object: T) async throws
    
    // Deletes an object from Core Data.
    func deleteObject(entityName: String, predicate: NSPredicate) async throws
    
    // Clears all objects of the specified entity type from Core Data.
    func clearEntity(entityName: String) throws
}

class CoreDataManager: ObservableObject, CoreDataManagerProtocol {
    
    let viewContext = PersistenceController.shared.container.viewContext
    
    private weak var shoppingListViewModel: ShoppingListViewModel?
    
    private static var shared: CoreDataManager?
    
    static func shared(with viewModel: ShoppingListViewModel? = nil) -> CoreDataManager {
        if shared == nil {
            shared = CoreDataManager(viewModel: viewModel)
        } else if let viewModel = viewModel {
            shared?.shoppingListViewModel = viewModel
        }
        
        return shared!
    }
    
    // Updated initializer
    init(viewModel: ShoppingListViewModel? = nil) {
        self.shoppingListViewModel = viewModel
    }
        
    // MARK: - Fetch/Get Functions
    @MainActor
    func fetch<T: NSManagedObject>(entityName: String, with predicate: NSPredicate? = nil, sortBy: String? = nil) async throws -> [T] {
        let fetchRequest = NSFetchRequest<T>(entityName: entityName)
        
        if let predicate = predicate {
            fetchRequest.predicate = predicate
        }
        
        if let sortBy = sortBy {
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: sortBy, ascending: true)]
        }
        
        return try viewContext.fetch(fetchRequest)
    }
        
    func updateObject<T: NSManagedObject>(object: T) async throws {
            do {
                // Check if the object already exists in Core Data
                let fetchRequest = NSFetchRequest<T>(entityName: T.entity().name ?? "")
                let objectID = object.objectID
                
                fetchRequest.predicate = NSPredicate(format: "SELF = %@", objectID)
                
                let results = try viewContext.fetch(fetchRequest)
                
                if let existingObject = results.first {
                    // Update the existing object with values from the provided object
                    for (key, value) in object.entity.attributesByName {
                        existingObject.setValue(object.value(forKey: key), forKey: key)
                    }
                } else {
                    // If the object doesn't exist, insert it
                    viewContext.insert(object)
                }
                
                // Save the context to persist changes
                try self.viewContext.save()
            } catch {
                self.viewContext.rollback() // Rollback in case of an error
                throw error
            }
        }
    
    func deleteFromCoreData(entityName: String,
                                    context: NSManagedObjectContext,
                                    predicate: NSPredicate?) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        
        if predicate != nil {
            fetchRequest.predicate = predicate
        }
        
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDeleteRequest.resultType = .resultTypeObjectIDs
        
        do {
            let deleteResult = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
            if let objectIDs = deleteResult?.result as? [NSManagedObjectID] {
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                
                DispatchQueue.main.async {
                    // 1. Force update the grouped dictionaries
                    self.shoppingListViewModel?.groupedItemsByStoreAndCategory = [:]
                    self.shoppingListViewModel?.updateGroupedItemsInternal()
                    
                    // 2. Notify observers
                    self.objectWillChange.send()
                    
                    // 3. Post notification for other views
                    NotificationCenter.default.post(
                        name: ShoppingNotification.forceUIRefresh.name,
                        object: nil
                    )
                }
            }
        } catch {
            ErrorAlertManager.shared.showDataError("Error deleting object from Core Data: \(error.localizedDescription)")

            print("Error deleting object from Core Data: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func notifyDataChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("CoreDataChanged"),
                object: nil
            )
        }
    }
    
    func deleteObject(entityName: String, predicate: NSPredicate) async throws {
        // Create a fetch request for the specified entity
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        fetchRequest.predicate = predicate
        
        do {
            // Fetch the objects matching the predicate
            let objects = try self.viewContext.fetch(fetchRequest)
            
            // Delete all fetched objects
            for object in objects {
                self.viewContext.delete(object)
            }
            
            // Save the context after deletion
            if self.viewContext.hasChanges {
                try self.viewContext.save()
                notifyDataChanged()
            }
        } catch {
            throw error // Re-throw the error to the caller
        }
    }
    
    // In CoreDataManager
    func deleteItems<T: NSManagedObject>(at offsets: IndexSet, in items: [T]) {
        // Create a context
        let context = viewContext
        
        // Delete each item from the context
        for index in offsets {
            context.delete(items[index])
        }
        
        // Save the context
        do {
            try context.save()
            
            // Just post notification for view models to update
            notifyDataChanged()
        } catch {
            ErrorAlertManager.shared.showDataError("Error deleting items: \(error.localizedDescription)")

            print("Error deleting items: \(error)")
        }
    }
    
    func clearEntity(entityName: String) throws {
        
    }
    
    // Fetch from Core Data
    func fetchFromCoreData<T: NSManagedObject>(entityName: String,
                                               context: NSManagedObjectContext,
                                               predicate: NSPredicate? = nil) throws -> [T] {
        let fetchRequest = NSFetchRequest<T>(entityName: entityName)
        
        if let predicate = predicate {
            fetchRequest.predicate = predicate
        }
        
        return try context.fetch(fetchRequest)
    }

    func fetch<T: NSFetchRequestResult>(entityName: String, with predicate: NSPredicate? = nil, sortBy: [NSSortDescriptor]) throws -> [T] {
      //  var sortDescriptor: NSSortDescriptor
        
        let request = NSFetchRequest<T>(entityName: entityName)
        
        if !sortBy.isEmpty {
           // sortDescriptor = NSSortDescriptor(key: sortBy, ascending: true)
            request.sortDescriptors = sortBy //[sortDescriptor]
        }
        
        if predicate != nil {
            request.predicate = predicate
        }
        
        do {
            let results = try self.viewContext.fetch(request)
            
            if !results.isEmpty {
                return results
            }
        } catch {
            ErrorAlertManager.shared.showDataError("Error fetch failed: \(error.localizedDescription)")

            print("Fetch Failed: \(error)")
        }
        
        return []
    }
}
