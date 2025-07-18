//
//  ToDoListViewModel.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 2/14/25.
//

import CoreData
import CoreLocation
import Foundation
import MapKit
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

    var mapViewFormattedAddress = Constants.emptyString
    var businessName = Constants.emptyString

    init(context: NSManagedObjectContext, isEditingExistingItem: Bool = false) {
        self.viewContext = context
        self.locationManager = LocationManager.shared

        super.init(isEditingExistingItem: isEditingExistingItem)
                
        loadCustomCategories()
                
        do {
            try context.save()
            Task { @MainActor in
                self.fetchToDoItems()
                self.updateGroupedToDoItems(updateExists: false)
            }
        } catch {
            ErrorAlertManager.shared.showDataError("❌ Failed to save To-Do item: \(error.localizedDescription)")
        }
    }

    // MARK: - Fetch To-Do Items
    func fetchToDoItems() {
        do {
            toDoItems = try CoreDataManager.shared().fetch(entityName: CoreDataEntities.toDoItem.stringValue, sortBy: [NSSortDescriptor(keyPath: \ToDoItemEntity.dueDate, ascending: true)])
        } catch {
            ErrorAlertManager.shared.showDataError("❌ Failed to fetch To-Do items: \(error.localizedDescription)")
        }
    }
    
    func saveToDoItem(toDoItem: ToDoItemEntity?,
                      taskName: String,
                      selectedCategory: String,
                      addressOrLocationName: String,
                      needsLocation: Bool,
                      dueDate: Date,
                      priority: Int16,
                      latitude: Double?,
                      longitude: Double?) async {
        var newOrUpdatedToDoItem: ToDoItemEntity?
        
        Task {
            if toDoItem == nil {
                newOrUpdatedToDoItem = self.toToDoItem(
                    task: taskName,
                    category: selectedCategory,
                    addressOrLocationName: needsLocation ? addressOrLocationName : Constants.emptyString,
                    lastUpdate: Date(),
                    lastEditor: Constants.emptyString,
                    latitude: latitude ?? 0,
                    longitude: longitude ?? 0,
                    isCompleted: false,
                    dueDate: dueDate,
                    priority: priority
                )
            } else if let item = toDoItem {
                item.task = taskName
                item.category = selectedCategory
                item.addressOrLocationName = needsLocation ? addressOrLocationName : Constants.emptyString
                item.lastUpdated = Date()
                item.lastEditor = Constants.emptyString
                item.latitude = latitude ?? 0
                item.longitude = longitude ?? 0
                item.dueDate = dueDate
                item.priority = priority
                
                newOrUpdatedToDoItem = item
            }
            
            if let item = newOrUpdatedToDoItem {
                await self.saveToDoItemToCoreData(item: item)
                
                if let dueDate = item.dueDate {
                    scheduleDueDateNotification(for: item, dueDate: dueDate)
                }
                
                if let uid = item.uid {
                    // Only monitor if the item has a location (user selected "Item Needs Location" and chose a location)
                    if !(item.addressOrLocationName?.isEmpty ?? true) && item.latitude != 0 && item.longitude != 0 {                        self.locationManager.monitorRegionAtLocation(center: CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude),identifier: uid,item: item)
                    }
                }
            }
        }
        
        RatingHelper.shared.requestRatingAfterItemAddition()
    }
    
    private func scheduleDueDateNotification(for item: ToDoItemEntity, dueDate: Date) {
        let taskName = item.task ?? "To-Do Task"
        let identifier = "todo_due_\(item.uid ?? UUID().uuidString)"
        
        // Cancel any existing notification for this item
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        // Only schedule if the due date is in the future
        if dueDate > Date() {
            NotificationDelegate.shared.scheduleNotification(
                title: "Task Due",
                body: "Your task '\(taskName)' is due now.",
                dueDate: dueDate,
                identifier: identifier
            )
            print("✅ Scheduled due date notification for task: \(taskName) at \(dueDate)")
        } else {
            print("⚠️ Due date is in the past, not scheduling notification for: \(taskName)")
        }
    }
        
    func createDefaultToDoItem() -> ToDoItemEntity {
        let item = ToDoItemEntity(context: viewContext)
        item.uid = UUID().uuidString
        item.task = Constants.emptyString
        item.category = "Uncategorized"
        item.addressOrLocationName = Constants.emptyString
        item.lastUpdated = Date()
        item.lastEditor = "User"
        item.latitude = 0.0
        item.longitude = 0.0
        item.isCompleted = false
        item.dueDate = Date()
        item.priority = 2 // Medium priority by default
        
        return item
    }
    
    private func toToDoItem(task: String,
                            category: String,
                            addressOrLocationName: String,
                            lastUpdate: Date,
                            lastEditor: String,
                            latitude: Double,
                            longitude: Double,
                            isCompleted: Bool,
                            dueDate: Date?,
                            priority: Int16) -> ToDoItemEntity {
        let item = ToDoItemEntity(context: viewContext)
        item.uid = UUID().uuidString
        item.task = task
        item.category = category
        item.addressOrLocationName = addressOrLocationName
        item.lastUpdated = lastUpdate
        item.lastEditor = lastEditor
        item.latitude = latitude  // Make sure these are being set
        item.longitude = longitude // Make sure these are being set
        item.isCompleted = isCompleted
        item.dueDate = dueDate
        item.priority = priority
        
        // Print debug information
        print("📍 Creating new item with location - Lat: \(latitude), Lon: \(longitude)")
        
        return item
    }
    
    func saveToDoItemToCoreData(item: ToDoItemEntity) async {
        let context = viewContext
        
        do {
            try await MainActor.run {
                try context.save()
                print("📍 Saved item with location - Lat: \(item.latitude), Lon: \(item.longitude)")
            }
            
            await MainActor.run {
                self.fetchToDoItems()
                self.updateGroupedToDoItems(updateExists: false)
                DataUpdateManager.shared.objectWillChange.send()
            }
        } catch {
            ErrorAlertManager.shared.showDataError("❌ Failed to save To-Do item: \(error.localizedDescription)")
        }
        
        businessName = Constants.emptyString
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
    
    func lookupBusinessName(from address: String, completion: @escaping (String?) -> Void) {
        // First, geocode the address to get coordinates
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                print("❌ Geocoding error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                print("❌ No location found for address")
                completion(nil)
                return
            }
            
            // Create a search request using the coordinates
            let searchRequest = MKLocalSearch.Request()
            searchRequest.naturalLanguageQuery = "restaurant" // or "business" or "store"
            searchRequest.region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 100, // Search within 100 meters
                longitudinalMeters: 100
            )
            
            // Create and start the search
            let search = MKLocalSearch(request: searchRequest)
            search.start { response, error in
                if let error = error {
                    print("❌ Business lookup error: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                // Get the first result
                if let firstItem = response?.mapItems.first {
                    // Get just the business name
                    if let busName = firstItem.name {
                        print("✅ Found business: \(busName)")
                        
                        if self.businessName.isEmpty || !self.businessName.contains(busName) {
                            self.businessName = busName
                            
                            completion(self.businessName)  // Only return the business name
                        }
                    }
                    
                    completion(nil)
                    
                } else {
                    print("❌ No business found at address")
                    completion(nil)
                }
            }
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
            ErrorAlertManager.shared.showDataError("❌ Error deleting item: \(error.localizedDescription)")
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
            await saveToDoItemToCoreData(item: item)
        }
        
        if !completed {
            if let locationIdentifier = item.value(forKey: "uid") as? String {
                locationManager.monitorRegionAtLocation(center: CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude), identifier: locationIdentifier, item: item ?? createDefaultToDoItem())
            }
        } else {
            if let locationIdentifier = item.value(forKey: "uid") as? String {
                locationManager.checkAndUpdateRegionMonitoring(for: locationIdentifier)
            }
        }
        
        objectWillChange.send()
        
        RatingHelper.shared.requestRatingAfterTaskCompletion()
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
