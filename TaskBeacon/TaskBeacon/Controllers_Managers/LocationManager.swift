// MARK: - Location Manager
//
//  LocationManager.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/5/25.
//

import CoreData
import CloudKit
import CoreLocation
import Foundation
import MapKit
import SwiftUI
import UIKit
import UserNotifications

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    // Singleton instance
    static let shared = LocationManager()
    
    @Published var userLocation: CLLocation?
    @Published var isFetching: Bool = false
    @Published var stores: [MKMapItem] = []
    @Published var mkMapItems: [MKMapItem] = []
    @Published var noStoresFound = false
    @Published var currentLocation: CLLocation?
    @Published var storeOptions: [StoreOption] = []
    @Published var filteredStoreOptions: [StoreOption] = []
    @Published var searchQuery: String = ""
    @Published var selectedCategory: String? = nil
    @Published var selectedLocation: MKMapItem?
    @Published var errorMessage: String = Constants.emptyString
    @Published var showErrorAlert = false

    let maxDistanceMeters: Double = 64373.6 // 40336 // 25 miles, or use 64373.6 for 40 miles

    private let locationManager = CLLocationManager()

    var ignoredFirstEntryRegionIDs: Set<String> = []
    var regionIDToItemMap: [String: NSManagedObject] = [:]
    
    // Add a cache dictionary
    private var storeCategoryCache: [String: String] = [:]
    private var storeOptionCache: [String: StoreOption] = [:]
    
    // Closure to handle location updates
    var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?
    
    // Closure to handle authorization changes
    var onAuthStatusChange: ((CLAuthorizationStatus) -> Void)?

    var notifiedRegionIDs: Set<String> = []
    
    // Store a reference to the view context for Core Data operations
    var viewContext: NSManagedObjectContext?
    
    // MARK: - Store Search with Caching
    // Cache for storing previously found stores
    private var storeCache: [StoreOption] = []
    private var lastStoreCacheUpdate: Date = .distantPast
    private let storeCacheValidityDuration: TimeInterval = 3600 // 1 hour
    
    // Add to LocationManager class
    private var isInitialized = false
    private var lastMonitoringTime: Date?
    private let monitoringDebounceInterval: TimeInterval = 5.0

    // Make initializer private to enforce singleton pattern
    private override init() {
        super.init()
        
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        // Configure location manager
        locationManager.delegate = self
        
        #if targetEnvironment(simulator)
        // Use less aggressive settings for simulator
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 50.0
        #else
        // Use more precise settings for real devices
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 10.0
        locationManager.allowsBackgroundLocationUpdates = true
        #endif
        
        // Request authorization
        locationManager.requestAlwaysAuthorization()
        
        userLocation = locationManager.location
        currentLocation = userLocation
        
        // Start updating location
        locationManager.startUpdatingLocation()
        
        userLocation = locationManager.location
        currentLocation = userLocation
        
        UNUserNotificationCenter.current().delegate = self
    }
    
    // Add method to initialize with items
    // In LocationManager.swift
    func initializeWithItems(_ items: [NSManagedObject], context: NSManagedObjectContext? = nil) {
        guard !isInitialized else { return }
        isInitialized = true
        
        // Store the context from the first item (if available) or use provided context
        if let firstItem = items.first {
            viewContext = firstItem.managedObjectContext
        } else if let providedContext = context {
            viewContext = providedContext
        }
        
        userLocation = locationManager.location
        currentLocation = userLocation
        
        // Populate regionIDToItemMap
        for item in items {
            if let uid = item.value(forKey: "uid") as? String {
                let latitude = item.value(forKey: "latitude") as? Double ?? 0.0
                let longitude = item.value(forKey: "longitude") as? Double ?? 0.0
                
                // Check if this item should be monitored based on its type
                let shouldMonitor = shouldMonitorItem(item, latitude: latitude, longitude: longitude)
                
                if shouldMonitor {
                    print("\n\nitem ::: \(item)\n\n")
                    print("this lat ::: \(latitude) ::: \(longitude)")
                    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    monitorRegionAtLocation(center: coordinate, identifier: uid, item: item)
                }
            }
        }
        
//        for item in items {
//            if let uid = item.value(forKey: "uid") as? String {
//                let latitude = item.value(forKey: "latitude") as? Double ?? 0.0
//                let longitude = item.value(forKey: "longitude") as? Double ?? 0.0
//                
//                print("\n\nitem ::: \(item)\n\n")
//                print("this lat ::: \(latitude) ::: \(longitude)")
//                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
//
//                monitorRegionAtLocation(center: coordinate, identifier: uid, item: item)
//            }
//        }
    }
    
    private func shouldMonitorItem(_ item: NSManagedObject, latitude: Double, longitude: Double) -> Bool {
        // Must have valid coordinates
        guard latitude != 0, longitude != 0 else { return false }
        
        // Check entity type and specific conditions
        if item.entity.name == "ToDoItemEntity" {
            // To-Do items: only monitor if they have a location name (meaning user selected a location)
            let addressOrLocationName = item.value(forKey: "addressOrLocationName") as? String ?? ""
            return !addressOrLocationName.isEmpty
        } else if item.entity.name == "ShoppingItemEntity" {
            // Shopping items: only monitor if they have an assigned store
            let storeName = item.value(forKey: "storeName") as? String ?? ""
            return !storeName.isEmpty
        }
        
        return false
    }
    
    func loadStores() async {
        print("🔄 Loading stores... userLocation : \(String(describing: userLocation)) currentLocation : \(String(describing: currentLocation))")
        
        await MainActor.run { self.isFetching = true }
                
        // If we already have stores, don't fetch again
        if !self.stores.isEmpty {
            print("✅ Already have \(stores.count) stores, skipping fetch")
            await MainActor.run { isFetching = false }
            return
        }
        
        // Use the userLocation passed to this view directly, not from locationManager
        if let location = userLocation {
            print("📍 Using passed userLocation for store search")
            await self.searchNearbyStores()
        } else if let managerLocation = self.currentLocation {
            print("📍 Using manager's current location for store search")
            await self.searchNearbyStores()
        } else {
            print("⚠️ No location available for store search")
            await MainActor.run { self.isFetching = true }
        }
    }
    
    func searchNearbyStores(userQuery: String? = nil) async {
        await MainActor.run { self.isFetching = true }
        
        // Get current user location directly from CLLocationManager
        let locationManager = CLLocationManager()
        
        guard let currentLocation = locationManager.location?.coordinate else {
            print("❌ No location available for search")
            await MainActor.run {
                self.isFetching = false
                self.errorMessage = "Location not available"
                self.showErrorAlert = true
            }
            return
        }
                
        print("📍 Using current location for searchNearbyStores: \(currentLocation.latitude), \(currentLocation.longitude)")
        let searchCenter = currentLocation

        var allStores: [MKMapItem] = []
        var uniqueKeys = Set<String>()

        let majorChains = ["Target", "Walmart", "Costco", "Best Buy", "CVS", "Walgreens"]
        let searchTerms = ["store", "shop", "market", "mall", "supercenter", "home", "improvement", "retailer", "retail"]

        if let userQuery = userQuery, !userQuery.isEmpty {
            // 1. If userQuery matches a major chain, search for it first
            let isMajorChain = majorChains.contains { userQuery.localizedCaseInsensitiveContains($0) }
            if isMajorChain {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = userQuery
                request.region = MKCoordinateRegion(
                    center: searchCenter,
                    latitudinalMeters: 10000,
                    longitudinalMeters: 10000
                )
                do {
                    let results = try await performSearch(with: request)
                    for store in results {
                        let key = "\(store.name ?? "")|\(store.placemark.title ?? "")"
                        if !uniqueKeys.contains(key) {
                            allStores.append(store)
                            uniqueKeys.insert(key)
                        }
                    }
                    print("✅ Found \(results.count) stores for major chain '\(userQuery)'")
                } catch {
                    print("❌ Error searching for major chain '\(userQuery)': \(error)")
                }
            }

            // 2. Search with variations of the user query
            let searchVariations = [
                userQuery,
                "\(userQuery) store",
                "\(userQuery) shop",
                userQuery.replacingOccurrences(of: "store", with: "").trimmingCharacters(in: .whitespaces)
            ]
            for variation in searchVariations {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = variation
                request.region = MKCoordinateRegion(
                    center: searchCenter,
                    latitudinalMeters: 10000,
                    longitudinalMeters: 10000
                )
                do {
                    let results = try await performSearch(with: request)
                    for store in results {
                        let key = "\(store.name ?? "")|\(store.placemark.title ?? "")"
                        if !uniqueKeys.contains(key) {
                            allStores.append(store)
                            uniqueKeys.insert(key)
                        }
                    }
                    print("✅ Found \(results.count) stores for '\(variation)'")
                } catch {
                    print("❌ Error searching for '\(variation)': \(error)")
                }
            }
        } else {
            // 3. No user query: search for all major chains first
            for chain in majorChains {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = chain
                request.region = MKCoordinateRegion(
                    center: searchCenter,
                    latitudinalMeters: 10000,
                    longitudinalMeters: 10000
                )
                do {
                    let results = try await performSearch(with: request)
                    for store in results {
                        let key = "\(store.name ?? "")|\(store.placemark.title ?? "")"
                        if !uniqueKeys.contains(key) {
                            allStores.append(store)
                            uniqueKeys.insert(key)
                        }
                    }
                    print("✅ Found \(results.count) stores for major chain '\(chain)'")
                } catch {
                    print("❌ Error searching for major chain '\(chain)': \(error)")
                }
            }
            // 4. Then search with generic terms
            for term in searchTerms {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = term
                request.region = MKCoordinateRegion(
                    center: searchCenter,
                    latitudinalMeters: 10000,
                    longitudinalMeters: 10000
                )
                do {
                    let results = try await performSearch(with: request)
                    for store in results {
                        let key = "\(store.name ?? "")|\(store.placemark.title ?? "")"
                        if !uniqueKeys.contains(key) {
                            allStores.append(store)
                            uniqueKeys.insert(key)
                        }
                    }
                    print("✅ Found \(results.count) stores for '\(term)'")
                } catch {
                    print("❌ Error searching for '\(term)': \(error)")
                }
            }
        }

        // 5. Remove duplicates (already handled above), sort if needed
        let finalStores: [MKMapItem]
        if let userQuery = userQuery, !userQuery.isEmpty {
            finalStores = sortStoresByRelevance(allStores, query: userQuery)
        } else {
            finalStores = allStores
        }
        
        // Use the current location for filtering
        guard let filterLocation = locationManager.location else {
            print("❌ No location available for filtering stores")
            await MainActor.run {
                self.isFetching = false
                self.errorMessage = "Location not available for filtering stores"
                self.showErrorAlert = true
            }
            return
        }
        
        let filteredStores = finalStores.filter { store in
            guard let storeLocation = store.placemark.location else { return false }
            return storeLocation.distance(from: filterLocation) <= maxDistanceMeters
        }
        
        // Update the store list
        await MainActor.run {
            self.stores = filteredStores
            self.isFetching = false
            print("✅ Total unique stores found: \(filteredStores.count)")
        }
    }
    
    // Helper function to categorize stores
    func categoryForStore(name: String) -> String {
        let lowerName = name.lowercased()
        
        // Check for direct matches in our dictionary
        for (storeName, category) in Constants.knownStoreCategories {
            if lowerName.contains(storeName) {
                switch category {
                case "Hardware", "Home & Furniture":
                    return "Home Improvement"
                case "Department Store", "Wholesale", "Discount":
                    return Constants.generalMerchandise
                case "Grocery":
                    return Constants.groceryAndFood
                case "Apparel":
                    return "Clothing & Apparel"
                case "Electronics":
                    return "Electronics"
                case "Pharmacy":
                    return "Health & Beauty"
                default:
                    return "Specialty Stores"
                }
            }
        }
        
        // Enhanced categorization based on keywords
        if lowerName.contains("target") || lowerName.contains("walmart") || lowerName.contains("costco") {
            return Constants.generalMerchandise
        } else if lowerName.contains("home depot") || lowerName.contains("lowes") || lowerName.contains("hardware") {
            return "Home Improvement"
        } else if lowerName.contains("best buy") || lowerName.contains("electronic") {
            return "Electronics"
        } else if lowerName.contains("market") || lowerName.contains("grocery") || lowerName.contains("food") {
            return Constants.groceryAndFood
        } else if lowerName.contains("pharmacy") || lowerName.contains("drug") {
            return "Health & Beauty"
        } else if lowerName.contains("mall") || lowerName.contains("shopping center") {
            return "Specialty Stores"
        } else if lowerName.contains("department") || lowerName.contains("retail") || lowerName.contains("store") {
            return Constants.generalMerchandise
        }
        
        return "Specialty Stores" // <-- fixed typo
    }
    
    func determineStoreCategory(_ store: MKMapItem) -> String {
        // Create a cache key from store name and address
        let cacheKey = "\(store.name ?? "")-\(store.placemark.title ?? "")"
        
        // Check cache first
        if let cachedCategory = storeCategoryCache[cacheKey] {
            return cachedCategory
        }
        
        // If not in cache, determine category
        let category: String
        if #available(iOS 14.0, *), let poiCategory = store.pointOfInterestCategory {
            switch poiCategory.rawValue {
            case "MKPOICategoryElectronicsStore": category = "Electronics"
            case "MKPOICategorySupermarket": category = Constants.groceryAndFood
            case "MKPOICategoryPharmacy": category = "Health & Beauty"
            case "MKPOICategoryClothingStore": category = "Clothing & Apparel"
            case "MKPOICategoryDepartmentStore": category = Constants.generalMerchandise
            case "MKPOICategoryHardwareStore": category = "Home Improvement"
            default: category = categoryForStore(name: store.name ?? "")
            }
        } else {
            category = categoryForStore(name: store.name ?? "")
        }
        
        // Cache the result
        storeCategoryCache[cacheKey] = category
        
        // Only print unmatched stores once
        if category == "Specialty Stores" {
            print("Unmatched store: \(store.name ?? "Unknown") - Address: \(store.placemark.title ?? "")")
        }
        
        return category
    }
    
    // Add method to clear cache when needed
    func clearStoreCategoryCache() {
        storeCategoryCache.removeAll()
    }

    // Helper function to sort stores by relevance to the search query
    func sortStoresByRelevance(_ stores: [MKMapItem], query: String) -> [MKMapItem] {
        return stores.sorted { store1, store2 in
            let name1 = store1.name?.lowercased() ?? ""
            let name2 = store2.name?.lowercased() ?? ""
            let query = query.lowercased()
            
            // Exact matches first
            if name1 == query && name2 != query { return true }
            if name2 == query && name1 != query { return false }
            
            // Contains query
            if name1.contains(query) && !name2.contains(query) { return true }
            if name2.contains(query) && !name1.contains(query) { return false }
            
            // Partial matches
            let score1 = calculateRelevanceScore(name1, query: query)
            let score2 = calculateRelevanceScore(name2, query: query)
            return score1 > score2
        }
    }

    // Helper function to calculate relevance score
    private func calculateRelevanceScore(_ name: String, query: String) -> Int {
        var score = 0
        
        // Exact match
        if name == query { score += 100 }
        
        // Starts with query
        if name.hasPrefix(query) { score += 50 }
        
        // Contains query
        if name.contains(query) { score += 25 }
        
        // Contains words from query
        let queryWords = query.components(separatedBy: " ")
        for word in queryWords {
            if name.contains(word) { score += 10 }
        }
        
        return score
    }

    // Helper function to update store list
    private func updateStoreList(with stores: [MKMapItem]) {
        if !stores.isEmpty {
            print("✅ Found \(stores.count) unique stores after deduplication")
            self.stores = stores
            self.storeOptions = stores.compactMap { self.createStoreOption(from: $0) }
            self.noStoresFound = false
        } else {
            print("⚠️ No stores found after all searches")
            self.stores = []
            self.storeOptions = []
            self.noStoresFound = true
        }

        self.isFetching = false
    }
    
    // Function to perform a direct MapKit search
    func performDirectMapKitSearch() async {
        print("🔍 Performing direct MapKit search in EditableListView")
        
        // Get current user location from CLLocationManager
        let locationManager = CLLocationManager()
        let searchCenter: CLLocationCoordinate2D
        
        if locationManager.authorizationStatus == .authorizedWhenInUse ||
            locationManager.authorizationStatus == .authorizedAlways {
            
            if let currentLocation = locationManager.location?.coordinate {
                print("📍 Using current location for performDirectMapKitSearch: \(currentLocation.latitude), \(currentLocation.longitude)")
                searchCenter = currentLocation
            } else if let userLocation = self.userLocation {
                print("📍 Using saved user location for search")
                searchCenter = userLocation.coordinate
            } else {
                print("📍 No location available, waiting for user location")
                return
            }
        } else {
            print("📍 Location permission not granted, waiting for authorization")
            return
        }
        
        // Use multiple search terms for better results
        let searchTerms = ["store", "grocery", "supermarket", "walmart", "target"]
        
        // Create an array to store all search tasks
        var searchTasks: [Task<[MKMapItem], Error>] = []
        
        // Create a search task for each term
        for term in searchTerms {
            let task = Task {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = term
                request.region = MKCoordinateRegion(
                    center: searchCenter,  // Now searchCenter is non-optional
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                )
                
                return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[MKMapItem], Error>) in
                    let search = MKLocalSearch(request: request)
                    search.start { response, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let mapItems = response?.mapItems {
                            continuation.resume(returning: mapItems)
                        } else {
                            continuation.resume(returning: [])
                        }
                    }
                }
            }
            searchTasks.append(task)
        }
    }
    
    func storeExists(item: MKMapItem) -> Bool {
        for store in stores {
            print("item.name : \(String(describing: item.name)) ::: store.name : \(String(describing: store.name))")
            if let iName = item.name, let sName = store.name {
                if iName.contains(sName) {
                    print("item.placemark : \(item.placemark) ::: store.placemark : \(String(describing: store.placemark))")
                    if item.placemark == store.placemark {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    // In LocationManager
    func filterStores(searchQuery: String = "", category: String? = nil) -> [StoreOption] {
        var filtered = self.storeOptions
        
        // Apply search query filter
        if !searchQuery.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchQuery) ||
                $0.address.localizedCaseInsensitiveContains(searchQuery) ||
                $0.category.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        // Apply category filter if selected
        if let category = category, category != StoreCategory.allStores.displayName {
            filtered = filtered.filter { $0.category == category }
        }
        
        self.filteredStoreOptions = filtered
        
        return self.filteredStoreOptions
    }
    
    private func updateStoreOptions() {
        // Clear existing store options
        storeOptions.removeAll()
        
        // Create new store options from the consolidated stores
        for store in stores {
            if let storeOption = createStoreOption(from: store) {
                storeOptions.append(storeOption)
            }
        }
        
        // Sort store options by distance
        storeOptions.sort { $0.distance ?? 0.0 < $1.distance ?? 0.0 }
        
        // Update filtered store options based on current search query and category
         storeOptions = filterStores(searchQuery: searchQuery, category: selectedCategory)
        
        print("✅ Updated store options. Total stores: \(storeOptions.count)")
    }
    
    func createStoreOption(from store: MKMapItem) -> StoreOption? {
        guard let name = store.name else { return nil }
        
        // Create a cache key
        let cacheKey = "\(name)-\(store.placemark.title ?? "")"
        
        // Check cache first
        if let cachedOption = storeOptionCache[cacheKey] {
            return cachedOption
        }
        
        // Get address
        let address = getAddress(store)
        
        // Get category
        let category = determineStoreCategory(store)
        
        // Calculate distance
        let distance = calculateDistance(to: store)
        
        // Determine if this store is preferred
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<ShoppingItemEntity> = ShoppingItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "storeName == %@ AND storeAddress == %@",
                                             name, address)
        var isPreferred = false
        if let items = try? context.fetch(fetchRequest),
           let firstItem = items.first {
            isPreferred = firstItem.isPreferred
        }
        
        // Create UUID
        let uuid = UUID().uuidString
        
        let storeOption = StoreOption(
            storeID: uuid,
            name: name,
            price: 0.0,
            distance: distance,
            drivingDistance: 0,
            drivingTime: 0,
            address: address,
            category: category,
            isPreferred: isPreferred,
            mapItem: store
        )
        
        // Cache the result
        storeOptionCache[cacheKey] = storeOption
        
        return storeOption
    }
    
    // Add method to clear cache when needed
    func clearStoreOptionCache() {
        storeOptionCache.removeAll()
    }
    
    // Helper to calculate distance
    private func calculateDistance(to store: MKMapItem) -> CLLocationDistance {
        var distance: CLLocationDistance = 0
        
        if let userCoordinate = userLocation,
           let storeLocation = store.placemark.location {
            // Convert CLLocationCoordinate2D to CLLocation
            let userLocation = CLLocation(latitude: userCoordinate.coordinate.latitude, longitude: userCoordinate.coordinate.longitude)
            distance = userLocation.distance(from: storeLocation)
        }
        
        return distance
    }
    
    // Helper to get address
    func getAddress(_ mapItem: MKMapItem) -> String {
        let placemark = mapItem.placemark
        var addressComponents: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }
        
        if let subThoroughfare = placemark.subThoroughfare {
            if let thoroughfare = placemark.thoroughfare, !thoroughfare.contains(subThoroughfare) {
                if !addressComponents.isEmpty {
                    addressComponents[0] = "\(subThoroughfare) \(addressComponents[0])"
                }
            } else if addressComponents.isEmpty {
                addressComponents.append(subThoroughfare)
            }
        }
        
        if let locality = placemark.locality {
            addressComponents.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        
        if let postalCode = placemark.postalCode {
            addressComponents.append(postalCode)
        }
        
        return addressComponents.joined(separator: ", ")
    }

    // Helper function to perform the actual search
    func performSearch(with request: MKLocalSearch.Request) async throws -> [MKMapItem] {
        return try await withCheckedThrowingContinuation { continuation in
            let search = MKLocalSearch(request: request)
            search.start { response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let mapItems = response?.mapItems {
                    continuation.resume(returning: mapItems)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func loadAndMonitorAllGeofences(from context: NSManagedObjectContext) {
        print("📍 Starting to load and monitor geofences...")

        // Store the context for future use
        self.viewContext = context

        // Clear existing geofences
        clearAllGeofences()

        do {
            // Fetch ToDo Items with locations
            let todoRequest = NSFetchRequest<NSManagedObject>(entityName: "ToDoItemEntity")
            todoRequest.predicate = NSPredicate(format: "latitude != 0 AND longitude != 0")
            let todoItems = try context.fetch(todoRequest)
            
            // Fetch Shopping Items with locations
            let shoppingRequest = NSFetchRequest<NSManagedObject>(entityName: "ShoppingItemEntity")
            shoppingRequest.predicate = NSPredicate(format: "latitude != 0 AND longitude != 0")
            let shoppingItems = try context.fetch(shoppingRequest)
            
            // Process all items
            for item in todoItems + shoppingItems {
                guard let uid = item.value(forKey: "uid") as? String,
                      let latitude = item.value(forKey: "latitude") as? Double,
                      let longitude = item.value(forKey: "longitude") as? Double else { continue }
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                
                monitorRegionAtLocation(center: coordinate, identifier: uid, item: item)
                
               // regionIDToItemMap[uid] = item
            }
        } catch {
            print("❌ Failed to load geofences: \(error.localizedDescription)")
            
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    // Helper function to clear geofences
    private func clearAllGeofences() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
          //  print("🛑 Stopped monitoring region: \(region.identifier)")
        }
      //  print("✅ Cleared all existing geofences.")
    }
    
    func monitorRegionAtLocation(center: CLLocationCoordinate2D, identifier: String, item: NSManagedObject) {
        print("in monitorRegionAtLocation ::: center ::: \(center) ::: identifer ::: \(identifier)")
        print("Currently monitored regions: \(locationManager.monitoredRegions.map { $0.identifier })")

        // Check if region is already being monitored
        let recentlyPresentedNotifications = NotificationDelegate.shared.recentlyPresentedNotifications
        
        print("bef isRegionMonitored recentlyPresentedNotifications ::: \(recentlyPresentedNotifications)")
        print("Is region monitored: \(locationManager.monitoredRegions.contains { $0.identifier == identifier })")
        
        if isRegionMonitored(identifier) && !recentlyPresentedNotifications.isEmpty {
            print("⚠️ Region \(identifier) is already being monitored, skipping")
            return
        }

        if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            let maxDistance = locationManager.maximumRegionMonitoringDistance
            
            let region = CLCircularRegion(center: center,
                                          radius: 500.0/*maxDistance*/, identifier: identifier)
            region.notifyOnEntry = true
            region.notifyOnExit = true
       
            locationManager.startMonitoring(for: region)
            print("✅ Started monitoring region: \(identifier)")
            print("Region details - Center: \(region.center), Radius: \(region.radius)")
            
            self.notifiedRegionIDs.insert(region.identifier)
            self.regionIDToItemMap[identifier] = item
            print("item ::: \(item)")
            print("regionIDToItemMap ::: \(self.regionIDToItemMap)")
            print("notifiedRegionIDs ::: \(self.notifiedRegionIDs)")
        }
    }

    // Helper to check if the region is monitored
    func isRegionMonitored(_ identifier: String) -> Bool {
        return locationManager.monitoredRegions.contains { $0.identifier == identifier }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
     //   print("❌ Monitoring failed for region: \(region?.identifier ?? "unknown")")
     //   print("Error: \(error.localizedDescription)")
        
        // Attempt to restart monitoring if it failed
        if let region = region {
            locationManager.startMonitoring(for: region)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Call the closure with the new authorization status
        onAuthStatusChange?(manager.authorizationStatus)

        if manager.authorizationStatus == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
            monitorItemLocations()
        }
    }

    func requestAuthorization() {
        let status = locationManager.authorizationStatus // Direct access
        
        switch status {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            print("✅ authorizedAlways")
            locationManager.startUpdatingLocation()
        case .authorizedWhenInUse:
            print("⚠️ Upgrade to always for background geofencing")
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            print("❌ Location access denied or restricted")
        @unknown default:
            print("❓ Unknown location status")
        }
    }

    // Update monitorItemLocations method to use NSManagedObject for both entity types
    func monitorItemLocations() {
        print("dhw monitorItemLocations")

        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            print("❌ Geofencing is not supported on this device")
            return
        }
        
        // Use our stored view context
        guard let context = viewContext else {
            print("❌ No Core Data context available. Set viewContext before calling this method.")
            return
        }
        
        do {
            // Fetch ToDo Items with locations
            let todoRequest = NSFetchRequest<NSManagedObject>(entityName: "ToDoItemEntity")
            todoRequest.predicate = NSPredicate(format: "latitude != 0 AND longitude != 0")
            let todoItems = try context.fetch(todoRequest)
            
            // Fetch Shopping Items with locations
            let shoppingRequest = NSFetchRequest<NSManagedObject>(entityName: "ShoppingItemEntity")
            shoppingRequest.predicate = NSPredicate(format: "latitude != 0 AND longitude != 0")
            let shoppingItems = try context.fetch(shoppingRequest)
            
            // Process all items
            for item in todoItems + shoppingItems {
                guard let uid = item.value(forKey: "uid") as? String,
                      let latitude = item.value(forKey: "latitude") as? Double,
                      let longitude = item.value(forKey: "longitude") as? Double else { continue }
                if locationManager.monitoredRegions.contains(where: { $0.identifier == uid }) {
                    continue
                }
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                monitorRegionAtLocation(center: coordinate, identifier: uid, item: item)
                
               // regionIDToItemMap[uid] = item
            }
            
            print("✅ Monitoring \(locationManager.monitoredRegions.count) regions")
        } catch {
            print("❌ Failed to fetch items with locations: \(error.localizedDescription)")
        }
    }
    
    func stopMonitoring(for item: NSManagedObject) {
        print("dhw stopMonitoring")

        if let uid = item.value(forKey: "uid") as? String {
            for region in locationManager.monitoredRegions {
                if region.identifier == uid {
                    locationManager.stopMonitoring(for: region)
                    print("Stopped monitoring region: \(region.identifier)")
                    
                    // Clean up all tracking sets
                    regionIDToItemMap.removeValue(forKey: region.identifier)
                    notifiedRegionIDs.remove(region.identifier)
                    NotificationDelegate.shared.recentlyPresentedNotifications.remove(region.identifier)
                    
                    print("🧹 Cleaned up all tracking for region: \(region.identifier)")
                    break
                }
            }
        }
    }

    func consolidateDuplicateStores() {
        print("🔄 Starting store consolidation...")
        print("📊 Initial store count: \(stores.count)")
        
        // Create a set to store unique addresses
        var uniqueAddresses = Set<String>()
        var consolidatedStores: [MKMapItem] = []
        
        for store in stores {
            let address = getAddress(store)
            if !uniqueAddresses.contains(address) {
                uniqueAddresses.insert(address)
                consolidatedStores.append(store)
            } else {
                print("⚠️ Found duplicate store at address: \(address)")
            }
        }
        
        // Update the stores array with consolidated stores
        stores = consolidatedStores
        print("✅ Final store count after consolidation: \(stores.count)")
        
        // Update the store options
        updateStoreOptions()
    }

    // MARK: - Store Search with Caching
    // Helper method to remove duplicate stores based on name and location
    func removeDuplicateStores(from stores: [MKMapItem]) -> [MKMapItem] {
        var uniqueStores: [MKMapItem] = []
        var seenNames = Set<String>()
        
        for store in stores {
            if let name = store.name, !seenNames.contains(name) {
                seenNames.insert(name)
                uniqueStores.append(store)
            }
        }
        
        return uniqueStores
    }

    // Add property for authorizationStatus if needed:
    var authorizationStatus: CLAuthorizationStatus {
        return locationManager.authorizationStatus
    }
}

extension LocationManager {
    // Calculate distance to a coordinate
    func calculateDistance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        guard let userCoordinate = userLocation else {
            print("⚠️ No user location available for distance calculation")
            return 0
        }
        
        let userCLLocation = CLLocation(latitude: userCoordinate.coordinate.latitude, longitude: userCoordinate.coordinate.longitude)
        let storeCLLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        return userCLLocation.distance(from: storeCLLocation)
    }
    
    // Format distance between user location and store
    func formatDistance(from userLocation: CLLocationCoordinate2D, to storeLocation: CLLocationCoordinate2D) -> String {
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let storeCLLocation = CLLocation(latitude: storeLocation.latitude, longitude: storeLocation.longitude)
        
        let distanceInMeters = userCLLocation.distance(from: storeCLLocation)
        let distanceInMiles = distanceInMeters / 1609.34 // Convert meters to miles
        
        if distanceInMiles < 0.1 {
            return "Very close"
        } else if distanceInMiles < 1 {
            return "Less than 1 mile away"
        } else if distanceInMiles < 10 {
            return String(format: "%.1f miles away", distanceInMiles)
        } else {
            return String(format: "%.0f miles away", distanceInMiles)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("ENTERED DID UPDATE LOCATIONS ::: userLocation : \(String(describing: userLocation))")

        guard let location = locations.last else { return }
        userLocation = location
        currentLocation = location
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("DID ENTER REGION ::: \(region.identifier)")
        print("Region state in didEnterRegion: \(region.identifier)")
        
        // In didEnterRegion:
        guard let item = regionIDToItemMap[region.identifier] else {
            print("❌ No item found for region: \(region.identifier)")
            return
        }

        // Get the item's uid
        if let itemUid = item.value(forKey: "uid") as? String {
            // Check if this item's uid is in notifiedRegionIDs
            if self.notifiedRegionIDs.contains(itemUid) {
                // Create notification content
                let content = UNMutableNotificationContent()
                
                // Get all items for this location
                let items = regionIDToItemMap.filter { $0.key == itemUid }
                    .map { $0.value }
                    .prefix(5)  // Limit to 5 items
                
                let itemNames = items.compactMap { item -> String? in
                    if let title = item.value(forKey: "title") as? String {
                        return title
                    }
                    return nil
                }
                
                if item.entity.name == "ToDoItemEntity" {
                    content.title = "To-Do Reminder"
                    if itemNames.count > 1 {
                        content.body = "You're near \(item.value(forKey: "addressOrLocationName") as? String ?? "your task location")! Don't forget to complete:\n• " + itemNames.joined(separator: "\n• ")
                    } else if let firstItem = itemNames.first {
                        content.body = "You're near \(item.value(forKey: "addressOrLocationName") as? String ?? "your task location")! Don't forget to complete: \(firstItem)"
                    }
                } else if item.entity.name == "ShoppingItemEntity" {
                    content.title = "Shopping Reminder"
                    if itemNames.count > 1 {
                        content.body = "You're near \(item.value(forKey: "storeName") as? String ?? "a store")! Don't forget to buy:\n• " + itemNames.joined(separator: "\n• ")
                    } else if let firstItem = itemNames.first {
                        content.body = "You're near \(item.value(forKey: "storeName") as? String ?? "a store")! Don't forget to buy: \(firstItem)"
                    }
                }
                
                content.sound = .default
                
                // Create and schedule the notification
                let request = UNNotificationRequest(identifier: region.identifier, content: content, trigger: nil)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("❌ Failed to schedule notification: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        self.showErrorAlert = true
                    }
                }
            }
        }
    }
    
    func checkAndUpdateRegionMonitoring(for locationIdentifier: String) {
        // Get all items for this location, using uid
        print(">>>> regionIDToItemMap ::: \(regionIDToItemMap) ::: locationIdentifer : \(locationIdentifier)")
        let items = regionIDToItemMap.filter { item in
            return item.key == locationIdentifier
        }
        
        // Check if any items are active
        let hasActiveItems = items.contains { item in
            return !(item.value.value(forKey: "isCompleted") as? Bool ?? true)
        }
        
        print("\n\n***** items ::: \(items)\n\n*****")
        
        // Stop monitoring and clean up all regions for this item
        for (regionID, item) in items {
            // Stop monitoring the region
            
            if let region = locationManager.monitoredRegions.first(where: { $0.identifier == regionID }) {
                print("✅ Stopped monitoring and cleaned up region: \(regionID) for item: \(locationIdentifier)")
                locationManager.stopMonitoring(for: region)
            }
            
            // Remove from regionIDToItemMap
            regionIDToItemMap.removeValue(forKey: regionID)
            notifiedRegionIDs.remove(locationIdentifier)
        }
    }
    
    func updateAllGeofenceRadii() {
        print("dhw updateAllGeofenceRadii")

        // Get the new radius from UserDefaults
        let newRadius = UserDefaults.standard.double(forKey: "geofenceRadius")
        
        // Stop monitoring all current regions
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        
        // Restart monitoring with new radius for all items
        for (identifier, item) in regionIDToItemMap {
            if let latitude = item.value(forKey: "latitude") as? Double,
               let longitude = item.value(forKey: "longitude") as? Double {
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                monitorRegionAtLocation(center: coordinate, identifier: identifier, item: item)
                
              //  regionIDToItemMap[identifier] = item
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("dhw did exit region")

        guard let region = region as? CLCircularRegion else { return }
        
        print("⬅️ Exited region: \(region.identifier)")
     //   notifiedRegionIDs.remove(region.identifier) // Allow future entry notifications
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Location manager error: \(error.localizedDescription)")
        
        // Check if the error is a location unknown error
        if let error = error as? CLError {
            if error.code == .locationUnknown || error.code == .denied {
                // Use Utah fallback coordinates
                let fallbackCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
                onLocationUpdate?(fallbackCoordinate)
            }
        }
    }
}

extension MKMapItem: @retroactive Identifiable {
    public var id: String {
        return placemark.name ?? UUID().uuidString
    }
}

// Add extension to MKMapItem to provide a uniqueIdentifier for deduplication
extension MKMapItem {
    var uniqueIdentifier: String {
        let name = self.name?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        let address = self.placemark.title?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        let latitude = String(format: "%.5f", self.placemark.coordinate.latitude)
        let longitude = String(format: "%.5f", self.placemark.coordinate.longitude)
        return "\(name)_\(address)_\(latitude),\(longitude)"
    }
}
