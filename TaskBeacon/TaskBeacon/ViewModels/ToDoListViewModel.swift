//
//  ToDoListViewModel.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 2/14/25.
//

import CoreData
import CoreLocation
import Foundation
import SwiftUI

class ToDoListViewModel: ListsViewModel {
    @Published var toDoItems: [ToDoItemEntity] = []
    @Published var groupedToDoItems: [String: [ToDoItemEntity]] = [:]
    @Published var allCategories: [String: [String]] = Constants.toDoCategories
    @Published var selectedLocationAddress: String = Constants.emptyString
    @Published var selectedLocationName: String = Constants.emptyString
    @Published var selectedLocation: CLLocationCoordinate2D?
    @Published var latitude: Double = 0.0
    @Published var longitude: Double = 0.0

    private var viewContext: NSManagedObjectContext
    private let customCategoriesKey = "CustomToDoCategories"
    private let locationManager: LocationManager

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        self.locationManager = LocationManager.shared

        super.init()        
        
        loadCustomCategories()
                
        do {
            try context.save()
            Task { @MainActor in
                self.fetchToDoItems()
                self.updateGroupedToDoItems(updateExists: false)
            }
        } catch {
            print("❌ Failed to save To-Do item: \(error.localizedDescription)")
            
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    // MARK: - Fetch To-Do Items
    func fetchToDoItems() {
        do {
            toDoItems = try CoreDataManager.shared().fetch(entityName: CoreDataEntities.toDoItem.stringValue, sortBy: [NSSortDescriptor(keyPath: \ToDoItemEntity.dueDate, ascending: true)])
        } catch {
            print("❌ Failed to fetch To-Do items: \(error.localizedDescription)")
            
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    func saveToDoItem(item: ToDoItemEntity) async {
        let context = viewContext
        
        do {
            try await MainActor.run {
                try context.save()
                print("📍 Saved item with location - Lat: \(item.latitude), Lon: \(item.longitude)")
            }
            
            await MainActor.run {
                self.fetchToDoItems()
                self.updateGroupedToDoItems(updateExists: false)
            }
        } catch {
            print("❌ Failed to save To-Do item: \(error.localizedDescription)")
            
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    func updateGroupedToDoItems(updateExists: Bool) {
        DispatchQueue.main.async {
            let validItems = self.toDoItems.filter { item in
                guard let category = item.category, !category.isEmpty else {
                    print("⚠️ Invalid ToDoItem detected: \(item)")
                    return false
                }
                return true
            }
            
            self.groupedToDoItems = Dictionary(grouping: validItems) { $0.category ?? "Uncategorized" }
                .mapValues { $0.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) } }
            
            self.refreshTrigger = UUID()
            self.objectWillChange.send()
        }
    }
    
    func deleteToDoItem(item: ToDoItemEntity) {
        guard let context = item.managedObjectContext else { return }
        context.delete(item)
        do {
            try context.save()
            fetchToDoItems() // <-- Always fetch after a change!
            updateGroupedToDoItems(updateExists: false) // If you use grouped data
        } catch {
            print("❌ Error deleting item: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    // Method to complete a shopping item
    func completeToDoItem(_ item: ToDoItemEntity, completed: Bool) {
        item.isCompleted = completed
        if completed {
            // Update last updated date when the item is marked as completed
            item.lastUpdated = Date()
        }
        
        // Save the item to Core Data
        Task {
            await saveToDoItem(item: item)
        }
        
        if !completed {
            if let locationIdentifier = item.value(forKey: "addressOrLocationName") as? String {
                locationManager.monitorRegionAtLocation(center: CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude), identifier: locationIdentifier)
            }
        } else {
            if let locationIdentifier = item.value(forKey: "addressOrLocationName") as? String {
                locationManager.checkAndUpdateRegionMonitoring(for: locationIdentifier)
            }
        }
        
        objectWillChange.send()
    }
    
    func removeCategory() {
        DispatchQueue.main.async {
            // Force UI refresh
            self.fetchToDoItems()
            self.updateGroupedToDoItems(updateExists: true)
        }
    }
    
    func getAllToDoCategories() -> [String: [String]] {
        var categories = Constants.toDoCategories
        
        // Get custom categories from UserDefaults
        if let customCategories = UserDefaults.standard.array(forKey: customCategoriesKey) as? [String] {
            // Add custom categories to the "Custom" section
            categories["Custom"] = customCategories
        }
        
        return categories
    }
    
    func addCustomCategory(_ category: String) {
        // Get existing custom categories
        var customCategories = UserDefaults.standard.array(forKey: customCategoriesKey) as? [String] ?? []
        
        // Add new category if it doesn't exist
        if !customCategories.contains(category) {
            customCategories.append(category)
            
            // Save updated list
            UserDefaults.standard.set(customCategories, forKey: customCategoriesKey)
            
            // Update published property
            allCategories = getAllToDoCategories()
            
            // Update active categories
            if activeCategories["Custom"] == nil {
                activeCategories["Custom"] = []
            }
            activeCategories["Custom"]?.append(category)
            
            // Post notification to update UI
            NotificationCenter.default.post(name: ToDoNotification.todoCategoriesUpdated.name, object: nil)
        }
    }
    
    func updateCustomCategory(from oldCategory: String, to newCategory: String) {
        // Get existing custom categories
        var customCategories = UserDefaults.standard.array(forKey: customCategoriesKey) as? [String] ?? []
        
        // Update the category if it exists
        if let index = customCategories.firstIndex(of: oldCategory) {
            customCategories[index] = newCategory
            
            // Save updated list
            UserDefaults.standard.set(customCategories, forKey: customCategoriesKey)
            
            // Update published property
            allCategories = getAllToDoCategories()
            
            // Update active categories
            if let index = activeCategories["Custom"]?.firstIndex(of: oldCategory) {
                activeCategories["Custom"]?[index] = newCategory
            }
            
            // Post notification to update UI
            NotificationCenter.default.post(name: ToDoNotification.todoCategoriesUpdated.name, object: nil)
        }
    }

    func removeCustomCategory(_ category: String) {
        // Get existing custom categories
        var customCategories = UserDefaults.standard.array(forKey: customCategoriesKey) as? [String] ?? []
        
        // Remove the category if it exists
        if let index = customCategories.firstIndex(of: category) {
            customCategories.remove(at: index)
            
            // Save updated list
            UserDefaults.standard.set(customCategories, forKey: customCategoriesKey)
            
            // Update published property
            allCategories = getAllToDoCategories()
            
            // Update active categories
            if let index = activeCategories["Custom"]?.firstIndex(of: category) {
                activeCategories["Custom"]?.remove(at: index)
            }
            
            // Post notification to update UI
            NotificationCenter.default.post(name: ToDoNotification.todoCategoriesUpdated.name, object: nil)
        }
    }
    
    private func loadCustomCategories() {
        allCategories = getAllToDoCategories()
    }
}
