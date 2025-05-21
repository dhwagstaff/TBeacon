import CoreData
import CoreLocation
import MapKit
import Network
import SwiftUI
import UserNotifications
import UIKit

struct UnifiedStoreSelectionView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    @EnvironmentObject private var dataUpdateManager: DataUpdateManager
    @EnvironmentObject var locationManager: LocationManager
    
    // State variables
    @State private var searchText = Constants.emptyString
    @State private var showLocationPicker = false
    @State private var selectedAddress = Constants.emptyString
    @State private var searchQuery = Constants.emptyString
    @State private var cannotFetch: Bool = false
    @State private var selectedCategoryIndex: Int = 0
    @State private var showCategoryFilters: Bool = false
    @State private var networkMonitor = NWPathMonitor()
    @State private var isNetworkAvailable = true
    @State private var hasTriedLocalSearch = false
    @State private var noStoresFound = false
    @State private var locationError = false
    @State private var filteredStores: [StoreOption] = []
    @State private var selectedCategory: String? = nil
    @State private var didSaveLocation: Bool = false
    @State private var selectedLatitude: Double = 0
    @State private var selectedLongitude: Double = 0
    @State private var selectedStoreName: String = ""
    @State private var selectedStoreAddress: String = ""
    @State private var activeCategories: [String] = [Constants.allStores]
    @State private var showErrorAlert = false
    @State private var errorMessage: String = ""
    
    @Binding var isPresented: Bool
    @Binding var selectedStoreFilter: String
    @Binding var storeName: String
    @Binding var storeAddress: String
    @Binding var selectedStore: MKMapItem?
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    
    static var processedStoresCache: [String: [String: [StoreOption]]] = [:]

//    private let categories = [Constants.allStores,
//                              Constants.generalMerchandise,
//                              Constants.groceryAndFood,
//                              "Clothing & Apparel",
//                              "Electronics",
//                              "Home Improvement",
//                              "Health & Beauty",
//                              "Specialty Stores"]
    
    private let categories = StoreCategory.allCases.map { $0.displayName }
    
    init(searchQuery: String = Constants.emptyString,
         cannotFetch: Bool = false,
         selectedCategoryIndex: Int = -1,
         showCategoryFilters: Bool = false,
         networkMonitor: NWPathMonitor = NWPathMonitor(),
         isNetworkAvailable: Bool = true,
         hasTriedLocalSearch: Bool = false,
         noStoresFound: Bool = false,
         locationError: Bool = false,
         filteredStores: [StoreOption] = [],
         selectedCategory: String? = nil,
         isPresented: Binding<Bool>,
         selectedStoreFilter: Binding<String>,
         storeName: Binding<String>,
         storeAddress: Binding<String>,
         selectedStore: Binding<MKMapItem?>,
         latitude: Binding<Double?>,
         longitude: Binding<Double?>) {
        self.searchQuery = searchQuery
        self.cannotFetch = cannotFetch
        self.selectedCategoryIndex = selectedCategoryIndex
        self.showCategoryFilters = showCategoryFilters
        self.networkMonitor = networkMonitor
        self.isNetworkAvailable = isNetworkAvailable
        self.hasTriedLocalSearch = hasTriedLocalSearch
        self.noStoresFound = noStoresFound
        self.locationError = locationError
        self.filteredStores = filteredStores
        self.selectedCategory = selectedCategory
        self._isPresented = isPresented
        self._selectedStoreFilter = selectedStoreFilter
        self._storeName = storeName
        self._storeAddress = storeAddress
        self._selectedStore = selectedStore
        self._latitude = latitude
        self._longitude = longitude
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.gray.opacity(0.1)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    searchField
                    categoryFilters
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal)

                    storeListView
                    statusMessagesView
                }
                .navigationTitle("Select Store")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(Constants.cancel) {
                            self.isPresented = false
                        }
                    }
                }
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            // Only reset if needed
            if selectedCategoryIndex != 0 {
                selectedCategoryIndex = 0
            }
            if selectedStoreFilter != Constants.allStores {
                selectedStoreFilter = Constants.allStores
            }
                        
            Task {
                await locationManager.searchNearbyStores(userQuery: searchQuery)
            }
            
            updateActiveCategories()
        }
        .onChange(of: locationManager.stores) {
            // Update active categories when stores change
            updateActiveCategories()
        }
        .task {
            // Only load stores if empty
            if locationManager.stores.isEmpty {
                await locationManager.loadStores()
                locationManager.consolidateDuplicateStores()
            }
            
            updateActiveCategories()
        }
        .onChange(of: searchQuery) {
            
            if !searchQuery.isEmpty {
                Task {
                    await performSearchWithQuery(searchQuery)
                }
            }
        }
        .onReceive(locationManager.$selectedLocation) { newLocation in
            if newLocation != nil {
                isPresented = false
            }
        }
    }
    
    // MARK: - UI Components
    
    private var searchField: some View {
        ZStack(alignment: .trailing) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
                
                TextField("Search stores...", text: $searchQuery)
                    .onSubmit {
                        // Debounce the search to avoid too many API calls
                        Task {
                            await performSearchWithQuery(searchQuery)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                    )
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 8)
                
                if locationManager.isFetching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.trailing, 8)
                } else if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        Task {
                            await locationManager.searchNearbyStores(userQuery: searchQuery)
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing, 24)
                }
            }
        }
    }
    
    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<activeCategories.count, id: \.self) { index in
                    StoreFilterButton(name: activeCategories[index],
                                      isSelected: index == selectedCategoryIndex
                    ) {
                        selectedCategoryIndex = index
                        selectedStoreFilter = activeCategories[index]
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    private var storeListView: some View {
        let groupedStores = processStores()
        
        return ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(groupedStores.keys.sorted(), id: \.self) { category in
                    if let stores = groupedStores[category], !stores.isEmpty {
                        StoreCategoryView(
                            category: category,
                            stores: stores,
                            onStoreSelected: selectStore,
                            userLocation: locationManager.userLocation,
                            locationManager: locationManager
                        )
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color.gray.opacity(0.1))
    }
    
    private struct StoreCategoryView: View {
        let category: String
        let stores: [StoreOption]
        let onStoreSelected: (StoreOption) -> Void
        let userLocation: CLLocation?
        let locationManager: LocationManager
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: getCategoryIcon(for: category))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Circle().fill(Color.blue))
                    
                    Text(category)
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                Rectangle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(height: 1)
                    .padding(.horizontal)
                
                LazyVStack(spacing: 0) {
                    ForEach(stores) { store in
                        StoreRowView(
                            store: store,
                            userLocation: userLocation,
                            locationManager: locationManager,
                            onSelect: { onStoreSelected(store) }
                        )
                        
                        if store.id != stores.last?.id {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            .padding(.horizontal)
        }
    }

    private struct StoreRowView: View {
        let store: StoreOption
        let userLocation: CLLocation?
        let locationManager: LocationManager
        let onSelect: () -> Void
        
        var body: some View {
            Button(action: onSelect) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(store.address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
//                    if let userLocation = locationManager.userLocationManager?.location {
                   if let userLocation = locationManager.userLocation {
                        let distance = userLocation.distance(from: CLLocation(
                            latitude: store.mapItem.placemark.coordinate.latitude,
                            longitude: store.mapItem.placemark.coordinate.longitude
                        ))
                        Text(formatDistance(distance))
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.trailing, 8)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        
        private func formatDistance(_ distance: CLLocationDistance) -> String {
            let formatter = MKDistanceFormatter()
            formatter.unitStyle = .abbreviated
            return formatter.string(fromDistance: distance)
        }
    }
    
    private var statusMessagesView: some View {
        Group {
            if locationManager.isFetching {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2.0)
                        .tint(.accentColor)
                        .padding()
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .shadow(radius: 5)
                        )
                    
                    Text("Finding stores...")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .padding()
            } else if locationError {
                locationErrorView
            } else if cannotFetch {
                networkErrorView
            } else if noStoresFound && !locationManager.isFetching {
                noStoresFoundView
            }
        }
    }
    
    private var locationErrorView: some View {
        VStack {
            Text("Location services are disabled")
                .font(.headline)
                .padding(.bottom, 4)
            Text("Enable location services in Settings to find stores near you")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .padding(.top, 8)
        }
        .padding()
    }
    
    private var networkErrorView: some View {
        VStack {
            Text("Cannot connect to internet")
                .font(.headline)
                .padding(.bottom, 4)
            Text("Check your connection and try again")
                .font(.subheadline)
                .foregroundColor(.gray)
            Button("Retry") {
                Task {
                    await locationManager.loadStores()
                }
            }
            .padding(.top, 8)
        }
        .padding()
    }
    
    private var noStoresFoundView: some View {
        VStack {
            Text("No stores found")
                .font(.headline)
                .padding(.bottom, 4)
            Text("Try a different search or location")
                .font(.subheadline)
                .foregroundColor(.gray)
            Button("Try Again") {
                retryFetchStores()
            }
            .padding(.top, 8)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isNetworkAvailable = path.status == .satisfied
                if self.isNetworkAvailable && self.cannotFetch {
                    self.cannotFetch = false
                    Task {
                        await locationManager.loadStores()
                    }
                } else if !self.isNetworkAvailable {
                    self.cannotFetch = true
                }
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    private func handleSearchResponse(response: MKLocalSearch.Response?, error: Error?) {
        locationManager.isFetching = false
        hasTriedLocalSearch = true
        
        if let error = error {
            print("Error searching for stores: \(error.localizedDescription)")
            //  stores = MKMapItem.createStaticStores()
            return
        }
        
        if let mapItems = response?.mapItems, !mapItems.isEmpty {
            locationManager.stores = mapItems
            noStoresFound = false
        } else {
            //  stores = MKMapItem.createStaticStores()
            noStoresFound = locationManager.stores.isEmpty
        }
        
        if locationManager.stores.isEmpty && !hasTriedLocalSearch {
            retryFetchStores()
        }
    }
    
    private func retryFetchStores() {
        // Try with a different search term using the passed userLocation parameter
        if let passedLocation = locationManager.userLocation {
            print("🔄 Retrying fetch with passed location")
            // Use the passed location for searching
            locationManager.isFetching = true
            
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "supermarket"  // Try a different term
            request.region = MKCoordinateRegion(
                center: passedLocation.coordinate,
                //                center: passedLocation.coordinate,
                latitudinalMeters: 10000,
                longitudinalMeters: 10000
            )
            
            // Continue with the search...
        } else {
            locationManager.isFetching = false
        }
    }
    
    private func handleRetryResponse(response: MKLocalSearch.Response?, error: Error?) {
        locationManager.isFetching = false
        
        if let error = error {
            print("Error retrying store search: \(error.localizedDescription)")
            //  stores = MKMapItem.createStaticStores()
            return
        }
        
        if let mapItems = response?.mapItems, !mapItems.isEmpty {
            locationManager.stores = mapItems
            noStoresFound = false
        } else {
            // If still no results, try with static stores
            //  stores = MKMapItem.createStaticStores()
            noStoresFound = locationManager.stores.isEmpty
        }
    }
    
    // Method to handle store selection
    private func selectStore(_ store: StoreOption) {
        // Update the parent view's bindings
        storeName = store.name
        storeAddress = store.address
        selectedStore = store.mapItem
        latitude = store.mapItem.placemark.coordinate.latitude
        longitude = store.mapItem.placemark.coordinate.longitude
        
        // Find the matching MKMapItem from our stores array
        if let selectedIndex = findStoreIndex(name: store.name, address: store.address) {
            locationManager.stores.move(fromOffsets: IndexSet(integer: selectedIndex), toOffset: 0)
        }
        
        // Post notification that a store was selected
        NotificationCenter.default.post(name: NSNotification.Name("StoreSelected"), object: nil)
        
        self.isPresented = false
    }
    
    // Helper to find store index
    private func findStoreIndex(name: String, address: String) -> Int? {
        return locationManager.stores.firstIndex { store in
            guard let storeName = store.name else { return false }
            let storeAddress = locationManager.getAddress(store)
            return storeName == name && storeAddress == address
        }
    }
    
    // MARK: - Store Processing Methods
    
    private func processStores() -> [String: [StoreOption]] {
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
        let groupedStores = Dictionary(grouping: storesToConsider, by: { $0.category })
        
        // Then sort each category's stores by distance
        let sortedGroupedStores = groupedStores.mapValues { stores in
            sortStoreOptions(stores)
        }

        // Defensive: If no categories, return all
        guard !activeCategories.isEmpty else { return sortedGroupedStores }

        // Defensive: If index is out of bounds, reset to 0
        let safeIndex = (selectedCategoryIndex >= 0 && selectedCategoryIndex < activeCategories.count) ? selectedCategoryIndex : 0
        let selectedCategory = activeCategories[safeIndex]

        let result: [String: [StoreOption]]
        if selectedCategory == Constants.allStores {
            // For "All Stores", return the complete groupedStores dictionary
            result = sortedGroupedStores
        } else {
            // For specific categories, return only that category's stores
            if let stores = sortedGroupedStores[selectedCategory] {
                result = [selectedCategory: stores]
            } else {
                result = [:]
            }
        }
        
        // Only cache if we have results
        if !result.isEmpty {
            Self.updateCache(key: cacheKey, value: result)
        }
        
        return result
    }

    // Add this static function to handle cache updates
    private static func updateCache(key: String, value: [String: [StoreOption]]) {
        processedStoresCache[key] = value
    }

    // Add a method to clear the cache when needed
    private static func clearProcessedStoresCache() {
        processedStoresCache.removeAll()
    }
    
    private func updateActiveCategories() {
        // Get the stores to consider: filtered by search if searching, otherwise all
        let storesToConsider: [StoreOption] = {
            if !searchQuery.isEmpty {
                // Only stores matching the search
                return locationManager.stores.compactMap { locationManager.createStoreOption(from: $0) }
                    .filter { store in
                        let nameMatches = store.name.lowercased().contains(searchQuery.lowercased())
                        let addressMatches = store.address.lowercased().contains(searchQuery.lowercased())
                        return nameMatches || addressMatches
                    }
            } else {
                // All stores
                return locationManager.stores.compactMap { locationManager.createStoreOption(from: $0) }
            }
        }()

        let groupedStores = Dictionary(grouping: storesToConsider, by: { $0.category })
        let foundCategories = categories.dropFirst().filter { groupedStores[$0]?.isEmpty == false }

        var newActiveCategories: [String] = []
        if foundCategories.count == 1 {
            // Only one category found, show just that
            newActiveCategories = [foundCategories.first!]
        } else if foundCategories.count > 1 {
            // Multiple categories, show "All Stores" plus the found ones
            newActiveCategories = [Constants.allStores] + foundCategories
        } else {
            // No categories found, fallback to "All Stores"
            newActiveCategories = [Constants.allStores]
        }

        if newActiveCategories != activeCategories {
            DispatchQueue.main.async {
                self.activeCategories = newActiveCategories
                if self.selectedCategoryIndex >= self.activeCategories.count {
                    self.selectedCategoryIndex = 0
                }
            }
        }
    }
    
    // Helper to check if a store should be included
    private func shouldIncludeStore(_ store: StoreOption) -> Bool {
        // Filter by category
        if selectedCategoryIndex > 0 && store.category != activeCategories[selectedCategoryIndex] {
            return false
        }
        
        // Filter by search query
        if !searchQuery.isEmpty {
            let nameMatches = store.name.lowercased().contains(searchQuery.lowercased())
            let addressMatches = store.address.lowercased().contains(searchQuery.lowercased())
            return nameMatches || addressMatches
        }
        
        return true
    }
    
    // Helper to sort store options
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
    
    // Filter stores based on search query and selected category
    private func performSearchWithQuery(_ query: String) async {
        print("in performSearchWithQuery query ::: \(query)")
        print("Task isCancelled: \(Task.isCancelled)")
        
//        guard let userLocation = locationManager.userLocationManager?.location else {
        guard let userLocation = locationManager.userLocation else {
            print("userLocation is nil, returning")
            return
        }
        
        await MainActor.run { locationManager.isFetching = true }
        
        var allStores: [MKMapItem] = []
        
        print("about to check if query is empty, query: '\(query)'")

        if query.isEmpty {
            // If query is empty, perform a broad search for stores
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "store"
            request.region = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: 10000,
                longitudinalMeters: 10000
            )
            
            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                allStores.append(contentsOf: response.mapItems)
            } catch {
                print("❌ Error performing broad search: \(error)")
            }
        } else {
            // Try different search variations for specific queries
            let searchVariations = [
                query,                    // Exact query (e.g., "Best Buy")
                "\(query) store",         // Add "store" (e.g., "electronic store")
                "\(query) shop",          // Add "shop"
                query.replacingOccurrences(of: "store", with: "").trimmingCharacters(in: .whitespaces) // Remove "store" if present
            ]
            
            for variation in searchVariations {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = variation
                request.region = MKCoordinateRegion(
                    center: userLocation.coordinate,
                    latitudinalMeters: 10000,
                    longitudinalMeters: 10000
                )
                
                do {
                    let search = MKLocalSearch(request: request)
                    let response = try await search.start()
                    print("✅ Found \(response.mapItems.count) stores for '\(variation)'")
                    allStores.append(contentsOf: response.mapItems)
                } catch {
                    print("❌ Error searching for '\(variation)': \(error)")
                }
            }
        }
        
        // Remove duplicates and sort by relevance
        let uniqueStores = locationManager.removeDuplicateStores(from: allStores)
        let sortedStores = locationManager.sortStoresByRelevance(uniqueStores, query: query)
        
        await MainActor.run {
            locationManager.stores = sortedStores
            locationManager.isFetching = false
            updateActiveCategories() // Update categories after new search
        }
    }
    
    private func updateFilters() {
        if !searchQuery.isEmpty {
            // Perform a new search with the query
            Task {
                await performSearchWithQuery(searchQuery)
            }
        } else {
            // Reset to default view
            locationManager.filterStores(searchQuery: "", category: selectedCategory)
            filteredStores = locationManager.filteredStoreOptions
        }
    }
}
