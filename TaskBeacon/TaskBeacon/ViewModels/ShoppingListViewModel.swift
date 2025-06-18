 //
//  ShoppingListViewModel.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 2/14/25.
//

import CoreData
import Foundation
import MapKit
import SwiftUI
import UserNotifications

class ShoppingListViewModel: ListsViewModel {
    @Published var shoppingItems: [ShoppingItemEntity] = []
    @Published var groupedShoppingItems: [String: [ShoppingItemEntity]] = [:]
    @Published var groupedItemsByStoreAndCategory: [String: [String: [ShoppingItemEntity]]] = [:]
    @Published var categories: [String] = []
    @Published var otherStores: [ShoppingItemEntity] = []
    @Published var isFetchingStores = false
    @Published var selectedStoreForNewItem: MKMapItem? = nil // 🆕
    @Published var emojiMap: [String: String] = [:]
    @Published var categoryOrder: [String] = []
    
    private let viewContext: NSManagedObjectContext
    private let locationManager: LocationManager
    
    // Debouncing and fetch control properties
    private var lastFetchTime: Date = .distantPast
    private var isFetching = false
    private var fetchingEnabled = true
    private let minimumFetchInterval: TimeInterval = 0.5 // 500ms minimum between fetches
    
    var totalItemCount: Int {
        shoppingItems.count
    }
    
    // Add to your ShoppingListViewModel
    var hasUnassignedItems: Bool {
        // Check if there are any items without a store
        return shoppingItems.contains { item in
            return item.storeName == nil || item.storeName!.isEmpty
        }
    }
    
    init(context: NSManagedObjectContext, isEditingExistingItem: Bool = false) {
        self.viewContext = context
        
        self.locationManager = LocationManager.shared
        
        super.init(isEditingExistingItem: isEditingExistingItem)
                        
        // ✅ Fetch ToDoItem and ShoppingItem from Core Data
        let todoRequest = ToDoItemEntity.fetchRequest()
        let shoppingRequest = ShoppingItemEntity.fetchRequest()
        
        do {
            let todos = try context.fetch(todoRequest)
            let shoppingItems = try context.fetch(shoppingRequest)
            let allItems = todos + shoppingItems
            
            // ✅ Initialize LocationManager with the combined items
            LocationManager.shared.initializeWithItems(allItems)
        } catch {
            print("❌ Failed to fetch items for LocationManager: \(error)")
            
            errorMessage = error.localizedDescription
            showErrorAlert = true
            
            LocationManager.shared.initializeWithItems([])
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleDataChange),
                name: NSNotification.Name("CoreDataObjectDeleted"),
                object: nil
            )
        }
        
        // Initial one-time setup
        fetchShoppingItemsOnce()
        
        // Set up notification observers for controlled fetching
        setupNotificationObservers()
        
        if emojiMap.isEmpty {
            emojiMap = loadEmojiMap()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleDataChange() {
        self.groupedItemsByStoreAndCategory = [:]
        self.updateGroupedItemsInternal()
        self.objectWillChange.send()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fetchItemsWithDebounce),
            name: ShoppingNotification.shoppingListUpdated.name,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fetchShoppingItemsOnce),
            name: ShoppingNotification.fetchShoppingItemsOnce.name,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(forceUIRefreshAfterSave),
            name: ShoppingNotification.forceUIRefreshAfterSave.name,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fetchItemsWithDebounce),
            name: ShoppingNotification.shoppingItemDeleted.name,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fetchItemsWithDebounce),
            name: ShoppingNotification.shoppingItemCompleted.name,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fetchItemsWithDebounce),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stopContinuousFetching),
            name: ShoppingNotification.stopContinuousFetching.name,
            object: nil
        )
    }
    
    @objc func fetchItemsWithDebounce() {
        guard fetchingEnabled else {
            print("🛑 Fetch skipped - fetching is disabled")
            return
        }
        
        let now = Date()
        guard !isFetching && now.timeIntervalSince(lastFetchTime) >= minimumFetchInterval else {
            print("⏱️ Fetch skipped - too soon after previous fetch")
            return
        }

        self.isFetching = true
        self.lastFetchTime = now
        
        // Perform fetch after a short delay to prevent rapid sequential fetches
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.fetchShoppingItems()
            
            // Allow next fetch after this completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isFetching = false
            }
        }
    }
    
    @objc func stopContinuousFetching() {
        print("🛑 Stopping continuous fetching")
        fetchingEnabled = false
    }
    
    @objc func fetchShoppingItemsOnce() {
        // Enable for just this one fetch, then disable again
        let wasEnabled = fetchingEnabled
        fetchingEnabled = true
        fetchShoppingItems()
        fetchingEnabled = wasEnabled
    }
    
    // New method specifically for updates after adding/saving items
    @objc func forceUIRefreshAfterSave() {
        print("🔄 Forcing UI refresh after save - bypassing fetch controls")
        
        // Temporarily enable fetching regardless of current state
        let wasEnabled = fetchingEnabled
        fetchingEnabled = true
        
        // Fetch items directly without debouncing
        fetchShoppingItems()
        
        // Force UI to update immediately with fresh data
        DispatchQueue.main.async {
            // Update the UI state
            self.objectWillChange.send()
            
            // Log what we have after refresh
            print("📋 After force refresh: \(self.shoppingItems.count) items")
            print("💼 Store groups: \(self.groupedItemsByStoreAndCategory.keys.joined(separator: ", "))")
            
            // For items in "Other" group, print them explicitly
            if let otherItems = self.groupedItemsByStoreAndCategory["Other"] {
                print("📦 'Other' group contains \(otherItems.count) categories")
                for (category, items) in otherItems {
                    print("  🔹 \(category): \(items.count) items")
                    for item in items {
                        print("    - \(item.name ?? "Unnamed") (ID: \(item.uid ?? "no-id"))")
                    }
                }
            }
            
            // Request UI components to refresh
            NotificationCenter.default.post(
                name: ShoppingNotification.forceUIRefresh.name,
                object: nil,
                userInfo: ["complete": true]
            )
        }
        
        // Restore previous state
        fetchingEnabled = wasEnabled
    }
    
    func fetchShoppingItems() {
        print("📥 fetchShoppingItems called - checking if enabled")
        
        guard fetchingEnabled else {
            print("🛑 Fetch skipped - fetching is disabled")
            return
        }
        
        do {
            let items: [ShoppingItemEntity] = try CoreDataManager.shared().fetch(entityName: CoreDataEntities.shoppingItem.stringValue, sortBy: [NSSortDescriptor(keyPath: \ShoppingItemEntity.dateAdded, ascending: false)])
            
            print("📦 Fetched \(items.count) items from Core Data")
            print("📝 Item names: \(items.compactMap { $0.name }.joined(separator: ", "))")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Always update the items array - remove duplicate check that was preventing updates
                self.shoppingItems = items
                
                print("📋 Fetch complete: \(self.shoppingItems.count) items")
                
                // Update grouped items
                self.updateGroupedItemsInternal()
                
                // Force UI refresh
                self.objectWillChange.send()
            }
        } catch {
            print("❌ Failed to fetch Shopping items: \(error.localizedDescription)")
            
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    func updateGroupedItemsInternal() {
        print("🔄 updateGroupedItemsInternal called with \(self.shoppingItems.count) items")
        
        // Group items by store name, using "Other" for unassigned items
        var intermediateGrouping: [String: [ShoppingItemEntity]] = [:]
        
        // CRITICAL: First clear the existing dictionary to avoid stale data
        self.groupedItemsByStoreAndCategory.removeAll()
        
        // Print all items for debugging
        for (index, item) in self.shoppingItems.enumerated() {
            print("🔹 Item \(index): \(item.name ?? "unnamed") | Store: \(item.storeName ?? "none") | ID: \(item.uid ?? "no-id")")
        }
        
        // First pass - group by store name
        for item in self.shoppingItems {
            let storeKey: String
            if let storeName = item.storeName, !storeName.isEmpty {
                storeKey = storeName
                print("  ➡️ Item \(item.name ?? "unnamed") assigned to store: \(storeName)")
            } else {
                storeKey = "Other" // Consistent key for unassigned items
                print("  ⚠️ Item \(item.name ?? "unnamed") has no store, using 'Other'")
            }
            
            if intermediateGrouping[storeKey] == nil {
                intermediateGrouping[storeKey] = []
            }
            intermediateGrouping[storeKey]?.append(item)
        }
        
        // Print diagnostics about grouping
        print("📊 Grouping diagnostics:")
        for (store, items) in intermediateGrouping {
            print("  🏬 Store '\(store)': \(items.count) items")
            if store == "Other" {
                print("  ℹ️ Unassigned items: \(items.compactMap { $0.name }.joined(separator: ", "))")
            }
        }
        
        // Second pass - create the nested dictionary for categories
        for (store, items) in intermediateGrouping {
            var categoryDict: [String: [ShoppingItemEntity]] = [:]
            
            // Group by category
            for item in items {
                let categoryKey = item.category ?? "Uncategorized"
                if categoryDict[categoryKey] == nil {
                    categoryDict[categoryKey] = []
                }
                categoryDict[categoryKey]?.append(item)
            }
            
            // Sort items in each category
            for (category, categoryItems) in categoryDict {
                categoryDict[category] = categoryItems.sorted {
                    ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast)
                }
            }
            
            // Remove empty categories
            categoryDict = categoryDict.filter { !$0.value.isEmpty }
            
            // Only add the store if it has non-empty categories
            if !categoryDict.isEmpty {
                self.groupedItemsByStoreAndCategory[store] = categoryDict
            }
        }
        
        // Force UI refresh with multiple mechanisms
        self.refreshTrigger = UUID()
        self.objectWillChange.send()
    }
    
    func updateGroupedItemsByStoreAndCategory(updateExists: Bool) {
        // Break up the complex expression for better compiler performance and reliability
        var intermediateGrouping: [String: [ShoppingItemEntity]] = [:]
        
        // First pass - group by store name
        for item in self.shoppingItems {
            // Print debug info to track this specific item
            print("📋 Processing item: \(item.name ?? "Unknown") - Store: \(item.storeName ?? "None") - Category: \(item.category ?? "None") - ID: \(item.objectID.uriRepresentation().lastPathComponent)")
            
            let storeKey: String
            if let storeName = item.storeName, !storeName.isEmpty {
                storeKey = storeName
                print("  ➡️ Assigned to store: \(storeName)")
            } else {
                storeKey = "Other" // Consistent key for unassigned items
                print("  ⚠️ No store assigned, using 'Other'")
            }
            
            if intermediateGrouping[storeKey] == nil {
                intermediateGrouping[storeKey] = []
                print("  🆕 Created new store group: \(storeKey)")
            }
            intermediateGrouping[storeKey]?.append(item)
        }
        
        // Print diagnostic information about the intermediate grouping
        print("📊 Intermediate grouping:")
        for (store, items) in intermediateGrouping {
            print("  🏬 Store '\(store)': \(items.count) items")
            if store == "Other" {
                print("  ℹ️ Unassigned items: \(items.compactMap { $0.name }.joined(separator: ", "))")
            }
        }
        
        // Second pass - create the nested dictionary for categories
        self.groupedItemsByStoreAndCategory = [:]
        for (store, items) in intermediateGrouping {
            var categoryDict: [String: [ShoppingItemEntity]] = [:]
            
            // Group by category
            for item in items {
                let categoryKey = item.category ?? "Uncategorized"
                if categoryDict[categoryKey] == nil {
                    categoryDict[categoryKey] = []
                    print("  🆕 Created new category '\(categoryKey)' for store '\(store)'")
                }
                categoryDict[categoryKey]?.append(item)
            }
            
            // Sort items in each category
            for (category, categoryItems) in categoryDict {
                // Sort by dateAdded (newest first)
                categoryDict[category] = categoryItems.sorted {
                    ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast)
                }
                print("  ✅ Sorted \(categoryItems.count) items in category '\(category)' for store '\(store)'")
            }
            
            // Remove empty categories
            let originalCount = categoryDict.count
            categoryDict = categoryDict.filter { !$0.value.isEmpty }
            if originalCount != categoryDict.count {
                print("  🧹 Removed \(originalCount - categoryDict.count) empty categories from store '\(store)'")
            }
            
            // Only add the store if it has non-empty categories
            if !categoryDict.isEmpty {
                self.groupedItemsByStoreAndCategory[store] = categoryDict
                print("  ✅ Added store '\(store)' with \(categoryDict.count) categories")
            } else {
                print("  ⚠️ Store '\(store)' has no items, skipping")
            }
        }
        
        // Force UI refresh
        self.refreshTrigger = UUID()
        self.objectWillChange.send()
        
        // Debug print to track what we've grouped
        let storesList = groupedItemsByStoreAndCategory.keys.sorted().joined(separator: ", ")
        print("🔄 Updated grouping complete - Stores: \(storesList)")
        
        // Print detailed statistics
        var totalItems = 0
        print("📊 Final grouping statistics:")
        for (store, categories) in groupedItemsByStoreAndCategory.sorted(by: { $0.key < $1.key }) {
            var storeItemCount = 0
            print("  🏬 Store: \(store)")
            
            for (category, items) in categories.sorted(by: { $0.key < $1.key }) {
                print("    📁 Category \(category): \(items.count) items")
                storeItemCount += items.count
            }
            
            print("    📊 Total items in store: \(storeItemCount)")
            totalItems += storeItemCount
        }
        
        print("📈 Grand total: \(totalItems) items in \(groupedItemsByStoreAndCategory.count) stores")
    }
    
    // Method to complete a shopping item
    func completeShoppingItem(_ item: ShoppingItemEntity, completed: Bool) {
        item.isCompleted = completed
        if completed {
            // Update last updated date when the item is marked as completed
            item.lastUpdated = Date()
        }
        
        // Save the item to Core Data
//        Task {
//            await saveShoppingItemToCoreData(item: item)
//        }
        
        if !completed {
            if let locationIdentifier = item.value(forKey: "uid") as? String {
                locationManager.monitorRegionAtLocation(center: CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude), identifier: locationIdentifier, item: item)
            }
        } else {
            if let locationIdentifier = item.value(forKey: "uid") as? String {
                locationManager.checkAndUpdateRegionMonitoring(for: locationIdentifier)
            }
        }
                        
        objectWillChange.send()
    }
    
    func createDefaultShoppingItem() -> ShoppingItemEntity {
        let item = ShoppingItemEntity(context: viewContext)
        item.uid = UUID().uuidString
        item.name = Constants.emptyString
        item.category = "Uncategorized"
        item.storeName = Constants.emptyString
        item.storeAddress = Constants.emptyString
        item.lastUpdated = Date()
        item.lastEditor = "User"
        item.latitude = 0.0
        item.longitude = 0.0
        item.isCompleted = false
        item.expirationDate = Date()
        item.priority = 2 // Medium priority by default
        item.brand = Constants.emptyString
        item.barcode = Constants.emptyString
        item.categoryEmoji = Constants.emptyString
        item.dateAdded = Date()
        item.emoji = Constants.emptyString
        item.gtin = Constants.emptyString
        item.isPreferred = false
        item.price = 0
        item.productImage = nil
        item.unitCount = 0
        item.volume = 0
        
        return item
    }
    
    func emojiForItemName(_ name: String) -> String {
        print("🔍 Looking for emoji for item name: \(name)")
        
        guard !name.isEmpty else {
            print("⚠️ Empty item name, returning default cart emoji")
            return "🛒"
        }
        
        let lower = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // First try direct word match
        let words = lower.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            if let emoji = emojiMap[word] {
                print("✅ Found exact match for word '\(word)' in '\(name)': \(emoji)")
                return emoji
            }
        }
        
        // Then try containing match
        for (keyword, emoji) in emojiMap {
            if lower.contains(keyword) {
                print("✅ Found substring match: '\(keyword)' in '\(name)': \(emoji)")
                return emoji
            }
        }
        
        // If no match, try individual words for partial matches
        for word in words {
            for (keyword, emoji) in emojiMap {
                if keyword.contains(word) && word.count > 2 {  // Only match words with at least 3 characters
                    print("✅ Found partial match: word '\(word)' matches keyword '\(keyword)': \(emoji)")
                    return emoji
                }
            }
        }
        
        print("❌ No emoji match found for '\(name)', returning default cart emoji")
        return "🛒"
    }
    
    func loadEmojiMap() -> [String: String] {
        print("in loadEmojiMap")
        guard let url = Bundle.main.url(forResource: "itemEmojis", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let emojiMap = try? JSONDecoder().decode([String: String].self, from: data) else {
            print("❌ Failed to load emoji map")
            return [:]
        }
        
        return emojiMap
    }
    
    func processStores(searchQuery: String, selectedCategoryIndex: Int) -> [String: [StoreOption]] {
        // Create a cache key based on current state
        let cacheKey = "\(selectedCategoryIndex)-\(searchQuery)"
        
        // Clear cache if it's the first time or if stores have changed
        if UnifiedStoreSelectionView.processedStoresCache.isEmpty || locationManager.stores.count != UnifiedStoreSelectionView.processedStoresCache.values.first?.values.first?.count {
            UnifiedStoreSelectionView.processedStoresCache.removeAll()
        }
        
        // Check if we have cached results for this state
        if let cachedResults = UnifiedStoreSelectionView.processedStoresCache[cacheKey] {
            // Only return cached results if they're not empty
            if !cachedResults.isEmpty {
                return cachedResults
            }
        }
        
        // Get all store options once
        let allStoreOptions = locationManager.stores.compactMap { locationManager.createStoreOption(from: $0) }
                
        // Filter based on search query if needed
        let storesToConsider: [StoreOption] = {
            if !searchQuery.isEmpty {
                return allStoreOptions.filter { store in
                    let nameMatches = store.name.lowercased().contains(searchQuery.lowercased())
                    let addressMatches = store.address.lowercased().contains(searchQuery.lowercased())
                    return nameMatches || addressMatches
                }
            } else {
                return allStoreOptions
            }
        }()

        // First group by category
//        var groupedStores = Dictionary(grouping: storesToConsider, by: { $0.category })
        
        // Add preferred stores category if there are any
        let context = PersistenceController.shared.container.viewContext

        let updatedStoresToConsider: [StoreOption] = storesToConsider.map { store in
            let fetchRequest: NSFetchRequest<ShoppingItemEntity> = ShoppingItemEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "storeName == %@ AND storeAddress == %@",
                                                 store.name, store.address)
            var updatedStore = store
            if let items = try? context.fetch(fetchRequest),
               let firstItem = items.first {
                updatedStore.isPreferred = firstItem.isPreferred
            } else {
                updatedStore.isPreferred = false
            }
            return updatedStore
        }
        
        // 1. Separate preferred and non-preferred stores
        let preferredStores = updatedStoresToConsider.filter { $0.isPreferred }
        let nonPreferredStores = updatedStoresToConsider.filter { !$0.isPreferred }

        // 2. Group only non-preferred stores by category
        var groupedStores = Dictionary(grouping: nonPreferredStores, by: { $0.category })

        // 3. Add preferred stores as their own category
        if !preferredStores.isEmpty {
            groupedStores["Preferred Stores"] = preferredStores
        }

        // 4. Remove any empty categories (defensive, in case of edge cases)
        groupedStores = groupedStores.filter { !$0.value.isEmpty }
        
        // Then sort each category's stores by distance
        let sortedGroupedStores = groupedStores.mapValues { stores in
            sortStoreOptions(stores)
        }

        // Defensive: If no categories, return all
        guard !activeCategories.isEmpty else { return sortedGroupedStores }
        
        let safeIndex = (selectedCategoryIndex >= 0 && selectedCategoryIndex < categoryOrder.count) ? selectedCategoryIndex : 0
        let selectedCategory = categoryOrder[safeIndex]

        let result: [String: [StoreOption]]
        if selectedCategory == Constants.allStores {
            // For "All Stores", return the complete groupedStores dictionary
            // Ensure Preferred Stores is first
            var orderedResult = [String: [StoreOption]]()
            if let preferred = sortedGroupedStores["Preferred Stores"] {
                orderedResult["Preferred Stores"] = preferred
            }
            // Add all other categories
            for (key, value) in sortedGroupedStores where key != "Preferred Stores" {
                orderedResult[key] = value
            }
            result = orderedResult
        } else {
            // For specific categories, still show preferred stores first
            var orderedResult = [String: [StoreOption]]()
            if let preferred = sortedGroupedStores["Preferred Stores"] {
                orderedResult["Preferred Stores"] = preferred
            }
            // Then add the selected category's stores
            if let stores = sortedGroupedStores[selectedCategory] {
                orderedResult[selectedCategory] = stores
            }
            result = orderedResult
        }
        
        // Only cache if we have results
        if !result.isEmpty {
            Self.updateCache(key: cacheKey, value: result)
        }
        
        return result
    }
    
    private static func updateCache(key: String, value: [String: [StoreOption]]) {
        UnifiedStoreSelectionView.processedStoresCache[key] = value
    }
    
    private func sortStoreOptions(_ options: [StoreOption]) -> [StoreOption] {
        return options.sorted { a, b in
            // Get user location
//            guard let userLocation = locationManager.userLocationManager?.location else {
            guard let userLocation = locationManager.userLocation else {
                return a.name < b.name // Fallback to alphabetical if no location
            }
            
            // Calculate distances
            let distanceA = userLocation.distance(from: CLLocation(
                latitude: a.mapItem.placemark.coordinate.latitude,
                longitude: a.mapItem.placemark.coordinate.longitude
            ))
            
            let distanceB = userLocation.distance(from: CLLocation(
                latitude: b.mapItem.placemark.coordinate.latitude,
                longitude: b.mapItem.placemark.coordinate.longitude
            ))
            
            // Sort by distance
            return distanceA < distanceB
        }
    }
    
    func saveShoppingItem(storeName: String,
                          shoppingItem: ShoppingItemEntity?,
                          name: String,
                          selectedCategory: String,
                          storeAddress: String,
                          latitude: Double?,
                          longitude: Double?,
                          expirationDate: Date,
                          selectedCategoryEmoji: String,
                          isPreferred: Bool) async {
        var itemToSave: ShoppingItemEntity!
        
        // All Core Data operations need to happen on the main thread
        Task {
            if let existingItem = shoppingItem {
                // Editing existing item
                itemToSave = existingItem
            } else {
                // Creating a new item
                itemToSave = ShoppingItemEntity(context: viewContext)
                itemToSave.id = UUID()
                itemToSave.uid = itemToSave.id?.uuidString
            }
            
            // Update item properties
            itemToSave.name = name
            itemToSave.category = selectedCategory
            itemToSave.storeName = storeName.isEmpty ? nil : storeName
            itemToSave.storeAddress = storeAddress.isEmpty ? nil : storeAddress
            
            if let lat = latitude, let long = longitude {
                itemToSave.latitude = lat
                itemToSave.longitude = long
            }
            
            if Constants.perishableCategories.contains(selectedCategory) {
                itemToSave.expirationDate = expirationDate
            } else {
                itemToSave.expirationDate = nil
            }
            
            itemToSave.lastUpdated = Date()
            
            // Set emoji if not already set
            if itemToSave.emoji == nil || itemToSave.emoji?.isEmpty == true {
                if emojiMap.isEmpty {
                    emojiMap = loadEmojiMap()
                }
                let emojiFromName = emojiForItemName(itemToSave.name ?? "")
                itemToSave.emoji = emojiFromName
                itemToSave.categoryEmoji = selectedCategoryEmoji
            }
            
            // Instead of saving and updating here, call the centralized function:
            await saveShoppingItemToCoreData(item: itemToSave)
            
            // Monitor region if needed
            if let uid = itemToSave.uid {
                // Only monitor if the shopping item has an assigned store
                if !(itemToSave.storeName?.isEmpty ?? true) &&
                   itemToSave.latitude != 0 &&
                   itemToSave.longitude != 0 {
                    locationManager.monitorRegionAtLocation(
                        center: CLLocationCoordinate2D(latitude: itemToSave.latitude, longitude: itemToSave.longitude),
                        identifier: uid,
                        item: itemToSave
                    )
                }
            }
            
//            if let uid = itemToSave.uid {
//                locationManager.monitorRegionAtLocation(
//                    center: CLLocationCoordinate2D(latitude: itemToSave.latitude, longitude: itemToSave.longitude),
//                    identifier: uid,
//                    item: itemToSave
//                )
//            }
        }
    }
    
//    func saveShoppingItem(storeName: String,
//                          shoppingItem: ShoppingItemEntity?,
//                          name: String,
//                          selectedCategory: String,
//                          storeAddress: String,
//                          latitude: Double?,
//                          longitude: Double?,
//                          expirationDate: Date,
//                          selectedCategoryEmoji: String,
//                          isPreferred: Bool) async {
//        do {
//            // Check if this is a store assignment
//            let isStoreAssignment = !storeName.isEmpty
//            
//            // CRITICAL: All Core Data operations need to happen on the main thread
//            await MainActor.run {
//                do {
//                    let itemToSave: ShoppingItemEntity
//                    
//                    if let existingItem = shoppingItem {
//                        // Editing existing item
//                        itemToSave = existingItem
//                    } else {
//                        // Creating a new item
//                        itemToSave = ShoppingItemEntity(context: viewContext)
//                        itemToSave.id = UUID()
//                        itemToSave.uid = itemToSave.id?.uuidString
//                    }
//                    
//                    // Update item properties
//                    itemToSave.name = name
//                    itemToSave.category = selectedCategory
//                    itemToSave.storeName = storeName.isEmpty ? nil : storeName
//                    itemToSave.storeAddress = storeAddress.isEmpty ? nil : storeAddress
//                    
//                    if let lat = latitude, let long = longitude {
//                        itemToSave.latitude = lat
//                        itemToSave.longitude = long
//                    }
//                    
//                    if Constants.perishableCategories.contains(selectedCategory) {
//                        itemToSave.expirationDate = expirationDate
//                    } else {
//                        itemToSave.expirationDate = nil
//                    }
//                    
//                    itemToSave.lastUpdated = Date()
//                    
//                    // Set emoji if not already set
//                    if itemToSave.emoji == nil || itemToSave.emoji?.isEmpty == true {
//                        // Make sure emoji map is loaded
//                        if emojiMap.isEmpty {
//                            emojiMap = loadEmojiMap()
//                        }
//                        
//                        // Get emoji from name or category
//                        let emojiFromName = emojiForItemName(itemToSave.name ?? "")
//                        itemToSave.emoji = emojiFromName
//                        itemToSave.categoryEmoji = selectedCategoryEmoji
//                    }
//                    
//                    // Now save the context
//                    try viewContext.save()
//                                        
//                    // Update grouping without triggering more fetches
//                    updateGroupedItemsInternal()
//                    
//                    if let uid = itemToSave.uid {
//                        locationManager.monitorRegionAtLocation(center: CLLocationCoordinate2D(latitude: itemToSave.latitude, longitude: itemToSave.longitude), identifier: uid, item: itemToSave)
//                        
//                      //  locationManager.regionIDToItemMap[uid] = itemToSave
//                    }
//                    
//                    // Update view model state directly
//                    objectWillChange.send()
//                } catch {
//                    print("❌ Error saving to Core Data on main thread: \(error.localizedDescription)")
//                }
//            }
//        }
//    }
    
    func saveShoppingItemToCoreData(item: ShoppingItemEntity) async {
        do {
            // Check if this is a store assignment
            let isStoreAssignment = item.storeName != nil && !item.storeName!.isEmpty
            
            // Save the item to Core Data
            try viewContext.save()
            
            // Fetch all items to update the view model
            let saved: [ShoppingItemEntity] = try await CoreDataManager.shared().fetch(entityName: CoreDataEntities.shoppingItem.stringValue)
            print("🗂 Total shopping items in Core Data: \(saved.count)")
            print("📝 Saved item names: \(saved.compactMap { $0.name }.joined(separator: ", "))")

            // Update the view model's data
            await MainActor.run {
                // Direct update to ensure immediate UI refresh
                self.shoppingItems = saved
                
                // If this was a store assignment, clear the grouping dictionary to force rebuild
                if isStoreAssignment {
                    self.groupedItemsByStoreAndCategory.removeAll()
                }
                
                // Update grouping without triggering more fetches
                self.updateGroupedItemsInternal()
                
                // Post a notification to inform other views about the change
                NotificationCenter.default.post(
                    name: ShoppingNotification.forceUIRefresh.name,
                    object: nil,
                    userInfo: ["complete": true, "isStoreAssignment": isStoreAssignment]
                )
                
                // Force send object change notification to SwiftUI
                self.objectWillChange.send()
                
                // For store assignments, do another update after a short delay
                if isStoreAssignment {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.updateGroupedItemsInternal()
                        self.objectWillChange.send()
                    }
                }
                
                // Print debug information about the grouping
                let storeKeys = self.groupedItemsByStoreAndCategory.keys.joined(separator: ", ")
                print("📊 Updated grouped items. Stores: \(storeKeys)")
            }

            print("✅ Saved ShoppingItem: \(item.name ?? "")")
        } catch {
            print("❌ Failed to save ShoppingItem: \(error.localizedDescription)")
            
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    func deleteShoppingItem(item: ShoppingItemEntity) {
        guard let context = item.managedObjectContext else { return }
        
        let category = item.category ?? "Unknown"
        let store = item.storeName ?? "Other"
        
        context.delete(item)
        
        do {
            try context.save()
            
            // Immediately update the in-memory shoppingItems array to remove the deleted item
            DispatchQueue.main.async {
                // Remove the deleted item from the shoppingItems array
                if let index = self.shoppingItems.firstIndex(where: { $0.objectID == item.objectID }) {
                    self.shoppingItems.remove(at: index)
                }
                
                // Update grouped items and remove empty categories
                self.updateGroupedItemsInternal()
                
                // Force UI update through SwiftUI
                self.objectWillChange.send()
                
                print("✅ Deleted item from category: \(category), store: \(store)")
            }
        } catch {
            print("❌ Error deleting item: \(error.localizedDescription)")
            
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    func beginAddFlow(completion: @escaping () -> Void) {
        print("🏪 Beginning store fetch for add flow")
        
        // First, make a static list of common stores for fallback
        let commonStores = [
            "Walmart", "Target", "Kroger", "Safeway", "Costco", 
            "Whole Foods", "Trader Joe's", "Publix", "Aldi"
        ]
        
        Task {
            print("🔍 Beginning store search for add flow")
            
            // Get the user's location (if available)
            LocationManager.shared.initializeWithItems([])

            let locationAvailable: Bool
            
            // Try to get user location from LocationManager
            if let location = locationManager.currentLocation {
                // Search using the actual user location
                print("📍 Using current location for store search")
                await locationManager.searchNearbyStores()
                locationAvailable = true
            } else {
                // Handle no location case properly
                print("⚠️ No location available for store search")
                locationAvailable = false
            }
            
            // UI updates must happen on main thread
            await MainActor.run {
                if locationAvailable && !locationManager.stores.isEmpty {
                    // If we found stores, use the nearest one (first in list)
                    if let nearest = locationManager.stores.first {
                        print("✅ Selected nearest store: \(nearest.placemark.name ?? "Unknown")")
                        self.selectedStoreForNewItem = nearest
                    } else {
                        print("⚠️ No stores found from search")
                        self.selectedStoreForNewItem = nil
                        
                        // Notify UI that no stores were found
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NoStoresFound"),
                            object: nil,
                            userInfo: ["commonStores": commonStores]
                        )
                    }
                } else {
                    // Handle the no-location case
                    print("⚠️ Location services unavailable")
                    self.selectedStoreForNewItem = nil
                    
                    // Notify UI about location services issue
                    NotificationCenter.default.post(
                        name: NSNotification.Name("LocationUnavailable"),
                        object: nil
                    )
                }
                
                // Always call completion regardless of store find status
                completion()
            }
        }
    }
    
    func getEstimatedExpirationDate(for category: String, item: String? = nil) -> Date? {
        print("Getting expiration date for category: \(category), item: \(item ?? "none")")
        
        // If we have a category and item name, try to find a specific match
        if let item = item, let categoryDict = Constants.expirationEstimates[category] {
            let itemName = item.lowercased()
            
            // Search through all subcategories for a matching item
            for (_, subcategoryItems) in categoryDict {
                // Try to find a matching item in this subcategory
                if let matchingItem = subcategoryItems.first(where: { (itemName, _) in
                    itemName.contains(itemName.lowercased())
                }) {
                    // Found a match, return the expiration date
                    let (_, daysToExpire) = matchingItem
                    print("📅 Found matching item '\(matchingItem.0)' in category '\(category)', setting expiration to \(daysToExpire) days")
                    return Calendar.current.date(byAdding: .day, value: daysToExpire, to: Date())
                }
            }
        }
        
        // If no specific match found, use category default
        if let defaultDays = Constants.getDefaultExpirationDays(for: category) {
            print("📅 No specific match found, using default expiration of \(defaultDays) days for category '\(category)'")
            return Calendar.current.date(byAdding: .day, value: defaultDays, to: Date())
        }
        
        print("⚠️ No expiration estimate found for category '\(category)'")
        return nil
    }

    func removeCategory() {
        DispatchQueue.main.async {
            // Force UI refresh
            self.fetchShoppingItems()
            self.updateGroupedItemsByStoreAndCategory(updateExists: true)
        }
    }
}

extension ShoppingListViewModel {
    // Add this new method to handle address-specific grouping
    func updateGroupedItemsWithDistinctLocations() {
        print("🔄 Running specialized grouping with distinct store locations...")
        
        // Group items by store name + address, using "Other" for unassigned items
        var intermediateGrouping: [String: [ShoppingItemEntity]] = [:]
        
        // CRITICAL: First clear the existing dictionary to avoid stale data
        self.groupedItemsByStoreAndCategory.removeAll()
        
        // First pass - group by store name + address
        for item in self.shoppingItems {
            // Create a composite key that includes both store name and address
            let storeKey: String
            if let storeName = item.storeName, !storeName.isEmpty {
                if let storeAddress = item.storeAddress, !storeAddress.isEmpty {
                    // Create a display-friendly composite key
                    storeKey = "\(storeName): \(storeAddress)"
                    print("  ➡️ Item \(item.name ?? "unnamed") assigned to specific location: \(storeKey)")
                } else {
                    storeKey = storeName // Fallback to just name if no address
                    print("  ➡️ Item \(item.name ?? "unnamed") assigned to store without address: \(storeName)")
                }
            } else {
                storeKey = "Other" // Consistent key for unassigned items
                print("  ⚠️ Item \(item.name ?? "unnamed") has no store, using 'Other'")
            }
            
            if intermediateGrouping[storeKey] == nil {
                intermediateGrouping[storeKey] = []
            }
            intermediateGrouping[storeKey]?.append(item)
        }
        
        // Second pass - create the nested dictionary for categories
        for (store, items) in intermediateGrouping {
            var categoryDict: [String: [ShoppingItemEntity]] = [:]
            
            // Group by category
            for item in items {
                let categoryKey = item.category ?? "Uncategorized"
                if categoryDict[categoryKey] == nil {
                    categoryDict[categoryKey] = []
                }
                categoryDict[categoryKey]?.append(item)
            }
            
            // Sort items in each category
            for (category, categoryItems) in categoryDict {
                categoryDict[category] = categoryItems.sorted {
                    ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast)
                }
            }
            
            // Remove empty categories
            categoryDict = categoryDict.filter { !$0.value.isEmpty }
            
            // Only add the store if it has non-empty categories
            if !categoryDict.isEmpty {
                self.groupedItemsByStoreAndCategory[store] = categoryDict
            }
        }
        
        // Force UI refresh with multiple mechanisms
        self.refreshTrigger = UUID()
        self.objectWillChange.send()
        
        print("✅ Distinct location grouping complete with \(groupedItemsByStoreAndCategory.count) unique store locations")
    }
}
