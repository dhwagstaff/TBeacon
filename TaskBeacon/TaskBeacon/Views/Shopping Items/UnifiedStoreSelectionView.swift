import CoreData
import CoreLocation
import MapKit
import Network
import SwiftUI
import UserNotifications
import UIKit

struct UnifiedStoreSelectionView: View {
    @AppStorage("preferredStoreName") private var preferredStoreName: String = ""
    @AppStorage("preferredStoreAddress") private var preferredStoreAddress: String = ""
    @AppStorage("preferredStoreLatitude") private var preferredStoreLatitude: Double = 0.0
    @AppStorage("preferredStoreLongitude") private var preferredStoreLongitude: Double = 0.0

    @Environment(\.presentationMode) private var presentationMode
    
    @EnvironmentObject private var dataUpdateManager: DataUpdateManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var viewModel: ShoppingListViewModel
    
    static var processedStoresCache: [String: [String: [StoreOption]]] = [:]
    
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
    @State private var selectedStoreName: String = Constants.emptyString
    @State private var selectedStoreAddress: String = Constants.emptyString
    @State private var activeCategories: [String] = [Constants.allStores]
    @State private var showErrorAlert = false
    @State private var errorMessage: String = Constants.emptyString
    @State private var isInitialLoading = true
    
    @Binding var isPresented: Bool
    @Binding var selectedStoreFilter: String
    @Binding var storeName: String
    @Binding var storeAddress: String
    @Binding var selectedStore: MKMapItem?
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var isPreferred: Bool
    
    private let categories = StoreCategory.allCases.map { $0.displayName }
    
    let selectedShoppingItem: ShoppingItemEntity?
        
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
         longitude: Binding<Double?>,
         isPreferred: Binding<Bool>,
         selectedShoppingItem: ShoppingItemEntity? = nil) {
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
        self._isPreferred = isPreferred
        
        self.selectedShoppingItem = selectedShoppingItem
    }
    
    var preferredBanner: some View {
        LinearGradient(
            colors: [Color(hex: "FFD300"), Color(hex: "005D5D").opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 20).clipShape(RoundedCorner(radius: 12, corners: [.topLeft, .topRight]))
    }
    
    var body: some View {
        let groupedStores = viewModel.processStores(searchQuery: searchQuery, selectedCategoryIndex: selectedCategoryIndex)
        
        NavigationView {
            ZStack {
                Color.gray.opacity(0.1)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    searchField
                    
                    if let preferredStores = groupedStores["Preferred Stores"], !preferredStores.isEmpty {
                        StoreCategoryView(
                            category: "Preferred Stores",
                            stores: preferredStores,
                            searchQuery: searchQuery,
                            selectedCategoryIndex: selectedCategoryIndex,
                            onStoreSelected: selectStore,
                            userLocation: locationManager.userLocation,
                            locationManager: locationManager
                        )
                        .padding([.leading, .trailing], 2)
                        .padding(.top, 5)
                    }
                                        
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal)
                        .padding([.top, .bottom], 10)
                    
                    categoryFilters
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
        .onChange(of: locationManager.stores) {
            // Update active categories when stores change
            updateActiveCategories()
        }
        .task {
            // UI State Resets (from .onAppear)
            if selectedCategoryIndex != 0 {
                selectedCategoryIndex = 0
            }
            if selectedStoreFilter != Constants.allStores {
                selectedStoreFilter = Constants.allStores
            }
            
            // Data Loading (from both .onAppear and .task)
            if locationManager.stores.isEmpty && isPresented {
                print("�� Loading stores for UnifiedStoreSelectionView...")
                // Load stores
                await locationManager.loadStores()
                locationManager.consolidateDuplicateStores()
                
                // Search nearby stores if needed
                await locationManager.searchNearbyStores(userQuery: searchQuery)
            }
            
            // Update categories (from both)
            updateActiveCategories()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isInitialLoading = false
                }
            }
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
                
                if locationManager.isFetching && !searchQuery.isEmpty {
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
                ForEach(0..<viewModel.categoryOrder.count, id: \.self) { index in
                    StoreFilterButton(name: viewModel.categoryOrder[index],
                                      isSelected: index == selectedCategoryIndex
                    ) {
                        selectedCategoryIndex = index
                        selectedStoreFilter = viewModel.categoryOrder[index]
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    private var storeListView: some View {
        let groupedStores = viewModel.processStores(searchQuery: searchQuery, selectedCategoryIndex: selectedCategoryIndex)
        
        return ScrollView {
            if selectedStoreFilter == Constants.allStores {
                // Show all non-preferred categories
                ForEach(viewModel.categoryOrder.filter { $0 != "Preferred Stores" && $0 != Constants.allStores }, id: \.self) { category in
                    if let stores = groupedStores[category], !stores.isEmpty {
                        StoreCategoryView(
                            category: category,
                            stores: stores,
                            searchQuery: searchQuery,
                            selectedCategoryIndex: selectedCategoryIndex,
                            onStoreSelected: selectStore,
                            userLocation: locationManager.userLocation,
                            locationManager: locationManager
                        )
                    }
                }
            } else if selectedStoreFilter != "Preferred Stores" {
                // Show only the selected category
                if let stores = groupedStores[selectedStoreFilter], !stores.isEmpty {
                    StoreCategoryView(
                        category: selectedStoreFilter,
                        stores: stores,
                        searchQuery: searchQuery,
                        selectedCategoryIndex: selectedCategoryIndex,
                        onStoreSelected: selectStore,
                        userLocation: locationManager.userLocation,
                        locationManager: locationManager
                    )
                }
            }
        }
        .background(Color.gray.opacity(0.1))
    }
    
    private struct StoreCategoryView: View {
        let category: String
        let stores: [StoreOption]
        let searchQuery: String
        let selectedCategoryIndex: Int
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
                        .padding(.top, 3)
                    
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
                        StoreRowView(store: store,
                                     category: category,
                                     searchQuery: searchQuery,
                                     selectedCategoryIndex: selectedCategoryIndex,
                                     userLocation: userLocation,
                                     locationManager: locationManager,
                                     onSelect: {
                                        onStoreSelected(store)
                                    }
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
        @AppStorage("preferredStoreName") private var preferredStoreName: String = ""
        @AppStorage("preferredStoreAddress") private var preferredStoreAddress: String = ""
        @AppStorage("preferredStoreLatitude") private var preferredStoreLatitude: Double = 0.0
        @AppStorage("preferredStoreLongitude") private var preferredStoreLongitude: Double = 0.0

        @EnvironmentObject var viewModel: ShoppingListViewModel

        let store: StoreOption
        let category: String
        let searchQuery: String
        let selectedCategoryIndex: Int
        let userLocation: CLLocation?
        let locationManager: LocationManager
        let onSelect: () -> Void
        
        private var isPreferredStore: Bool {
            viewModel.isPreferredStore(store)
        }
        
//        private var isPreferredStore: Bool {
//            return !preferredStoreName.isEmpty &&
//                   store.name == preferredStoreName &&
//                   store.address == preferredStoreAddress
//        }
        
        var body: some View {
            HStack {
                Button(action: {
                    viewModel.togglePreferredStore(isPreferredStore: isPreferredStore, store: store)
                   // togglePreferredStore()
                }) {
                    Image(systemName: isPreferredStore ? "star.fill" : "star")
                        .foregroundColor(isPreferredStore ? .yellow : .gray)
                        .font(.system(size: 16))
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.leading, 8)
                
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
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
        }
        
//        private func togglePreferredStore() {
//            if isPreferredStore {
//                // Clear preferred store
//                preferredStoreName = ""
//                preferredStoreAddress = ""
//                preferredStoreLatitude = 0.0
//                preferredStoreLongitude = 0.0
//                print("🗑️ Cleared preferred store")
//            } else {
//                // Set this store as preferred store
//                preferredStoreName = store.name
//                preferredStoreAddress = store.address
//                preferredStoreLatitude = store.mapItem.placemark.coordinate.latitude
//                preferredStoreLongitude = store.mapItem.placemark.coordinate.longitude
//                print("⭐ Set preferred store: \(store.name)")
//            }
//        }
        
        private func formatDistance(_ distance: CLLocationDistance) -> String {
            let formatter = MKDistanceFormatter()
            formatter.unitStyle = .abbreviated
            return formatter.string(fromDistance: distance)
        }
    }
    
    private var statusMessagesView: some View {
        Group {
            if isInitialLoading || locationManager.isFetching {
                LoadingOverlay()
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
        
        print("in selectStore storeName ::: \(storeName) ::: storeAddress ::: \(storeAddress)")
        
        if let item = selectedShoppingItem {
            Task {
                await viewModel.saveShoppingItem(
                    storeName: storeName,
                    shoppingItem: item,
                    name: item.name ?? "",
                    selectedCategory: item.category ?? "",
                    storeAddress: storeAddress,
                    latitude: latitude,
                    longitude: longitude,
                    expirationDate: item.expirationDate ?? Date(),
                    selectedCategoryEmoji: item.categoryEmoji ?? "",
                    isPreferred: isPreferred
                )
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isPresented = false
        }
    }
    
    // Helper to find store index
    private func findStoreIndex(name: String, address: String) -> Int? {
        return locationManager.stores.firstIndex { store in
            guard let storeName = store.name else { return false }
            let storeAddress = locationManager.getAddress(store)
            return storeName == name && storeAddress == address
        }
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
        
        let hasPreferredStores = locationManager.stores.compactMap { store in
            let context = PersistenceController.shared.container.viewContext
            let fetchRequest: NSFetchRequest<ShoppingItemEntity> = ShoppingItemEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "storeName == %@ AND storeAddress == %@",
                                                 store.name ?? "",
                                                 locationManager.getAddress(store))
            if let items = try? context.fetch(fetchRequest),
               let firstItem = items.first {
                return firstItem.isPreferred
            }
            return false
        }.contains(true)
        
        if hasPreferredStores {
            newActiveCategories.append("Preferred Stores")
        }
        
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
                viewModel.categoryOrder = newActiveCategories
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
        
    // Filter stores based on search query and selected category
    private func performSearchWithQuery(_ query: String) async {
        print("in performSearchWithQuery query ::: \(query)")
        print("Task isCancelled: \(Task.isCancelled)")
        
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
                    print("✅ performSearchWithQuery Found \(response.mapItems.count) stores for '\(variation)'")
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
            
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 second delay
                locationManager.isFetching = false
            }

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

struct RoundedCorner: Shape {
    var radius: CGFloat = 12.0
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
