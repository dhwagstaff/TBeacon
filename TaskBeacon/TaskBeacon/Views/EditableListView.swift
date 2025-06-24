//
//  EditableListView.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/5/25.
//

import AVFoundation
import CloudKit
import CoreData
import CoreLocation
import GoogleMobileAds
import MapKit
import SwiftUI
import UserNotifications

enum ToDoRow: Identifiable {
    case header(Priority)
    case categoryHeader(String)
    case item(ToDoItemEntity)
    case empty(Priority)
    
    var id: String {
        switch self {
        case .header(let p): return "header-\(p.rawValue)"
        case .categoryHeader(let category): return "category-\(category)"
        case .item(let item): return item.objectID.uriRepresentation().absoluteString
        case .empty(let p): return "empty-\(p.rawValue)"
        }
    }
}

enum TodoFilterType {
    case category
    case priority
    case none
}

// Helper view to force list refreshes when data changes
// This addresses SwiftUI's tendency to cache views and not update when collection data changes
struct ListReloadWrapper<Content: View>: View {
    let id: AnyHashable
    let content: () -> Content
    
    init(id: AnyHashable, @ViewBuilder content: @escaping () -> Content) {
        self.id = id
        self.content = content
    }
    
    var body: some View {
        content().id(id)
    }
}

struct EditableListView: View {
    @AppStorage("selectedSegment") private var selectedSegment = "To-Do"
    @AppStorage("preferredStoreName") private var preferredStoreName: String = ""
    @AppStorage("preferredStoreAddress") private var preferredStoreAddress: String = ""
    @AppStorage("preferredStoreLatitude") private var preferredStoreLatitude: Double = 0.0
    @AppStorage("preferredStoreLongitude") private var preferredStoreLongitude: Double = 0.0
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    
    @EnvironmentObject var dataUpdateManager: DataUpdateManager
    @EnvironmentObject var entitlementManager: EntitlementManager
    @EnvironmentObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject var todoListViewModel: ToDoListViewModel
    @EnvironmentObject var subscriptionsManager: SubscriptionsManager
    @EnvironmentObject var locationManager: LocationManager

    @StateObject private var quickActionManager = QuickActionsManager.shared
    @StateObject private var appDelegate = AppDelegate.shared
    @StateObject private var barcodeScannerViewModel = BarcodeScannerViewModel()
    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var preferredStoreManager = PreferredStoreManager()

    @State private var recentlyDeletedItem: (NSManagedObject, () -> Void)?
    @State private var showAddShoppingItem = false
    @State private var showAddTodoItem = false
    @State private var navigateToEditableList = false
    @State private var selectedShoppingItem: ShoppingItemEntity?
    @State private var selectedToDoItem: ToDoItemEntity?
    @State private var groupedShoppingItems: [String: [ShoppingItemEntity]] = [:]
    @State private var groupedToDoItems: [String: [ToDoItemEntity]] = [:]
    @State private var refreshTrigger: UUID = UUID()
    @State private var showSettings = false
    @State private var isScanning = false
    @State private var scannedBarcode: String?
    @State private var selectedProduct: Product?
    @State private var availableStores: [StoreOption] = []
    @State private var showStoreSelectionSheet = false
    @State private var showErrorMessage: String?
    @State private var isShowingAnySheet: Bool = false
    @State private var expandedStores: Set<String> = []
    @State private var expandedCategories: [String: Set<String>] = [:]
    @State private var unassignedItemsExpanded: Bool = false
    @State private var expandedCategoryMap: [String: Bool] = [:]
    @State private var scannedProduct: Product?
    @State private var scannedItem: ShoppingItemEntity?
    @State private var mkMapItems: [MKMapItem] = []
    @State private var stores: [MKMapItem] = []
    @State private var lastStoreAssignmentTime: Date? = nil
    @State private var forceViewUpdate: Bool = false
    @State private var isThrottled: Bool = false
    @State private var throttleErrorMessage: String? = nil
    @State private var throttleResetTime: Int = 0
    @State private var throttleTimer: Timer? = nil
    @State private var selectedStoreFilter: String = Constants.allStores
    @State private var storeName: String = Constants.emptyString
    @State private var storeAddress: String = Constants.emptyString
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var selectedStore: MKMapItem?
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var showUnassignedItemsInfo = false
    @State private var isPulsingInfoButton = false
    @State private var filterType: TodoFilterType = .none
    @State private var selectedPriority: Priority = .high
    @State private var isShowingLoadingOverlay = false
    @State private var expandedPriorities: Set<Priority> = Set(Priority.allCases)
    @State private var isPreferred: Bool = false
    @State private var taskBeaconRewardsIsShowing = false
    @State private var adCheckTimer: Timer?
    @State private var hasCancelledAd = false
    @State private var isShowingRewardedAd = false
    @State private var isShowingInterstitialAd = false
    @State private var showHelpView = false

    private static var isRefreshing = false
    // this may be needed for didenterregion and for todomap  private var userLocationManager: CLLocationManager?
        
    let todoRowHeight = 100.0
    
    private var filteredByPriorityItems: [ToDoItemEntity] {
        todoListViewModel.toDoItems.filter { $0.priority == selectedPriority.int16Value }
    }
    
    private var shouldShowRewardedAdSection: Bool {
        !entitlementManager.isPremiumUser && appDelegate.adManager.canRequestAds
    }

    private var shouldShowRewardedInterstitialAdView: Bool {
        shouldShowRewardedAdSection && !taskBeaconRewardsIsShowing && !appDelegate.adManager.isCancelled
    }
        
    // MARK: - Computed Properties
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.rectangle")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.secondary)
            Text("No To-Do Items Yet")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Tap the + button to add your first to-do item.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .background(Color(.systemBackground))
        .padding()
    }
    
    // Modified shoppingOrTodoList with reload wrapper
    private var shoppingOrTodoList: some View {
        VStack {
            ListReloadWrapper(id: refreshTrigger) {
                GeometryReader { geometry in
                    List {
                        if selectedSegment == "Shopping" {
                            shoppingListContent
                        } else { // TO DO'S
                            todoListContent
                                .frame(height: geometry.size.height * 0.9)
                        }
                    }
                    .listStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .onChange(of: shoppingListViewModel.shoppingItems) {
                        refreshTrigger = UUID()
                        shoppingListViewModel.updateGroupedItemsByStoreAndCategory(updateExists: true)
                    }
                }
            }
        }
    }
    
    // Shopping list content extracted into a separate builder
    @ViewBuilder
    private var shoppingListContent: some View {
        // Only show EmptyStateView if both shopping and todo lists are empty
        if shoppingListViewModel.shoppingItems.isEmpty && todoListViewModel.toDoItems.isEmpty {
            EmptyStateView()
                .environmentObject(shoppingListViewModel)
                .environmentObject(todoListViewModel)
                .listRowInsets(EdgeInsets())
                .frame(maxWidth: .infinity)
                .listRowBackground(Color(.systemBackground))
        } else if shoppingListViewModel.shoppingItems.isEmpty {
            // Show a simple empty message when only shopping list is empty
            Text("Your shopping list is empty")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .listRowBackground(Color(.systemBackground))
        } else {
           // shoppingListBanner
            unassignedItemsSection
            assignedItemsSection
        }
    }
    
    // Section for unassigned items
    @ViewBuilder
    private var unassignedItemsSection: some View {
        if let otherStore = shoppingListViewModel.groupedItemsByStoreAndCategory.keys.first(where: { $0 == "Other" || $0.isEmpty }) {
            Section {
                // Header row with disclosure arrow for unassigned items
                DisclosureGroup(
                    isExpanded: $unassignedItemsExpanded,
                    content: {
                        unassignedItemsCategoriesContent(otherStore: otherStore)
                    },
                    label: {
                        HStack {
                            Button(action: {
                                showUnassignedItemsInfo = true
                            }) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 16))
                                    .scaleEffect(isPulsingInfoButton ? 1.3 : 1.0)
                                    .opacity(isPulsingInfoButton ? 0.6 : 1.0)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .onAppear {
                                // Start the pulsing animation
                                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                                    withAnimation(.easeInOut(duration: 1.0)) {
                                        isPulsingInfoButton.toggle()
                                    }
                                }
                            }
                            
                            Text("Items without assigned stores")
                                .font(.headline)
                                .foregroundColor(.orange)
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                )
                .background(Color(.systemBackground))
                .listRowBackground(Color(.systemBackground))
                .id("unassigned-section-\(refreshTrigger)") // Add explicit ID for refresh
                .alert(isPresented: $showUnassignedItemsInfo) {
                    Alert(
                        title: Text("Store Assignment"),
                        message: Text("Items without assigned stores won't trigger location-based reminders. Assign stores to receive notifications when you're near a store location."),
                        dismissButton: .default(Text("Ok"))
                    )
                }
            }
        }
    }
    
    // Section for items with assigned stores
    @ViewBuilder
    private var assignedItemsSection: some View {
        // Then show items with assigned stores (everything except "Other")
        ForEach(Array(shoppingListViewModel.groupedItemsByStoreAndCategory.keys.sorted()), id: \.self) { store in
            // Skip the "Other" category since we already displayed it
            if store != "Other" && !store.isEmpty {
                Section {
                    DisclosureGroup {
                        // Categories and items
                        if let categories = shoppingListViewModel.groupedItemsByStoreAndCategory[store] {
                            ForEach(Array(categories.keys.sorted()), id: \.self) { category in
                                if let items = categories[category], !items.isEmpty {
                                    // Category header - match the same pattern as todo items
                                    DisclosureGroup(
                                        isExpanded: Binding(
                                            get: { expandedCategoryMap["\(store)_\(category)"] ?? false },
                                            set: { expandedCategoryMap["\(store)_\(category)"] = $0 }
                                        ),
                                        content: {
                                            shoppingItemsList(items: items)
                                        },
                                        label: {
                                            categoryLabel(category: category, items: items)
                                        }
                                    )
                                    .id("\(store)-\(category)-\(refreshTrigger)")
                                }
                            }
                        }
                    } label: {
                        // Store name and address in the same row
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "storefront.circle.fill")
                                    .imageScale(.large)
                                    .foregroundColor(.primary)

                                Text(store)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            
                            if let firstItem = shoppingListViewModel.groupedItemsByStoreAndCategory[store]?.values.first?.first,
                               let storeAddress = firstItem.storeAddress {
                                Text(storeAddress)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .listRowBackground(Color(.systemBackground))
                }
                .id("store-section-\(store)-\(refreshTrigger)")
            }
        }
    }
    
    private var addNewItemPrompt: some View {
        Section(header: Text("")) {
            VStack(spacing: 20) {
                Image(systemName: selectedSegment == "Shopping" ? "cart" : "list.bullet.rectangle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(selectedSegment == "Shopping" ? .blue : .green)
                Text("Tap the + button to add a \(selectedSegment == "Shopping" ? "shopping" : "to-do") item.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .background(Color(.systemBackground))
            .padding()
        }
    }
    
    // 🔹 Floating Action Button for Barcode Scanning
    private var scannerFAB: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    Task {
                        if await permissionManager.checkAndRequestPermission(for: .camera) {
                            isScanning = true
                        }
                    }
                }) {
                    Image(systemName: "barcode.viewfinder")
                        .imageScale(.large)
                        .foregroundColor(.blue)
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
    }
    
    private var itemTypePicker: some View {
        Picker("ItemType", selection: $selectedSegment) {
            Text("Shopping").tag("Shopping")
                .foregroundColor(selectedSegment == "Shopping" ? .blue : .primary)
                .fontWeight(.semibold)
                .frame(width: 100)
            
            Text("To-Do").tag("To-Do")
                .foregroundColor(selectedSegment == "To-Do" ? .green : .primary)
                .fontWeight(.semibold)
                .frame(width: 100)
        }
        .onChange(of: selectedSegment) {
            Task {
                switchItemType()
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
        
    // To-do list content extracted to a separate builder
    @ViewBuilder
    private var todoListContent: some View {
        switch filterType {
        case .none:
            List {
                ForEach(Priority.allCases) { priority in
                    Section(header: PrioritySectionHeader(priority: priority, itemCount: todoListViewModel.toDoItems.filter { $0.priority == priority.rawValue }.count)) {
                        let items = todoListViewModel.toDoItems.filter { $0.priority == priority.rawValue }
                        if items.isEmpty {
                            EmptyItemsView()
                        } else {
                            ForEach(items, id: \.objectID) { item in
                                ToDoItemRow(item: item, showCategory: filterType == .category)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: todoRowHeight)
                                    .onTapGesture {
                                        selectedToDoItem = item
                                        showAddTodoItem = true
                                        isShowingAnySheet = true
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                deleteToDoItem(item)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            
        case .priority:
            List {
                Section(header: PrioritySectionHeader(priority: selectedPriority, itemCount: filteredByPriorityItems.count)) {
                    if filteredByPriorityItems.isEmpty {
                        EmptyItemsView()
                    } else {
                        ForEach(filteredByPriorityItems, id: \.objectID) { item in
                            ToDoItemRow(item: item, showCategory: filterType == .category)
                                .frame(maxWidth: .infinity)
                                .frame(height: todoRowHeight)
                                .onTapGesture {
                                    selectedToDoItem = item
                                    showAddTodoItem = true
                                    isShowingAnySheet = true
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            deleteToDoItem(item)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            
        case .category:
            let grouped = Dictionary(grouping: todoListViewModel.toDoItems) { $0.category ?? "Uncategorized" }
            List {
                ForEach(grouped.keys.sorted(), id: \.self) { category in
                    Section(header: CategorySectionHeader(category: category, itemCount: grouped[category]?.count ?? 0)) {
                        if let items = grouped[category], !items.isEmpty {
                            ForEach(items, id: \.objectID) { item in
                                ToDoItemRow(item: item, showCategory: true)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: todoRowHeight)
                                    .onTapGesture {
                                        selectedToDoItem = item
                                        showAddTodoItem = true
                                        isShowingAnySheet = true
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                deleteToDoItem(item)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                            }
                        } else {
                            EmptyItemsView()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        var items: [NSManagedObject] = []
        
        let todoRequest = NSFetchRequest<ToDoItemEntity>(entityName: CoreDataEntities.toDoItem.stringValue)
        let shoppingRequest = NSFetchRequest<ShoppingItemEntity>(entityName: CoreDataEntities.shoppingItem.stringValue)
        
        do {
            let todos = try context.fetch(todoRequest)
            let shoppingItems = try context.fetch(shoppingRequest)
            
            items.append(contentsOf: todos)
            items.append(contentsOf: shoppingItems)
            
            print("✅ Fetched \(items.count) items for geofencing.")
        } catch {
            print("❌ Error fetching items: \(error)")
        }
        
        // Initialize the LocationManager singleton with fetched items
        LocationManager.shared.initializeWithItems(items)
        LocationManager.shared.viewContext = context
        
        // Set up dedicated user location manager
      // this may be needed for didenterregion and for todomap let manager = CLLocationManager()
        // We'll set the delegate in onAppear to avoid memory leaks
        // this may be needed for didenterregion and for todomap  self.userLocationManager = manager
    }
        
    var body: some View {
        NavigationView {
            VStack {
                if let product = selectedProduct {
                    ProductInfoView(product: product, stores: availableStores)
                }
                
                if shoppingListViewModel.shoppingItems.isEmpty && todoListViewModel.toDoItems.isEmpty {
                    EmptyStateView()
                        .environmentObject(shoppingListViewModel)
                        .environmentObject(todoListViewModel)
                } else {
                    itemTypePicker
                    if selectedSegment == "To-Do" {
                        HStack {
                            FilterMenuView(filterType: $filterType, selectedPriority: $selectedPriority)
                                                    
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                    }
                    
                    shoppingOrTodoList
                        .id("shopping-list-\(refreshTrigger)-\(forceViewUpdate)")
                }
                
                if isShowingLoadingOverlay {
                    LoadingOverlay()
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gearshape.fill")
                            .imageScale(.large)
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            showHelpView = true
                        }) {
                            Image(systemName: "questionmark.circle")
                                .imageScale(.large)
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: {
                            Task {
                                if await PermissionManager.shared.checkAndRequestPermission(for: .camera) {
                                    isScanning = true
                                }
                            }
                        }) {
                            Image(systemName: "barcode.viewfinder")
                                .imageScale(.large)
                                .foregroundColor(.blue)
                        }
                        
                        Menu {
                            Button {
                                selectedSegment = "Shopping"

                                // Show loading overlay
                                withAnimation(.easeIn(duration: 0.3)) {
                                    if locationManager.stores.isEmpty {
                                        isShowingLoadingOverlay = true
                                        
                                        shoppingListViewModel.beginAddFlow {
                                            showAddShoppingItem = true
                                            isShowingAnySheet = true
                                        }
                                    } else {
                                        isShowingLoadingOverlay = false
                                        showAddShoppingItem = true
                                        isShowingAnySheet = true
                                    }
                                }
                                
                                // Hide loading overlay after 3 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        isShowingLoadingOverlay = false
                                    }
                                }
                            } label: {
                                Label("Shopping Item", systemImage: ImageSymbolNames.cartFill)
                                    .foregroundColor(.blue)
                            }
                            
                            Button {
                                showAddTodoItem = true
                                selectedSegment = "To-Do"
                                isShowingAnySheet = true
                            } label: {
                                Label("To-Do Item", systemImage: "checklist")
                                    .foregroundColor(.green)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("")
            .sheet(isPresented: $showHelpView) {
                HelperView()
            }
            .sheet(isPresented: $isShowingRewardedAd, onDismiss: {
                appDelegate.adManager.lastAdTime = Date()
            }) {
                RewardedInterstitialContentView(isPresented: $isShowingRewardedAd, navigationTitle: "Task Beacon")
            }
            .sheet(isPresented: $isShowingInterstitialAd, onDismiss: {
                appDelegate.adManager.lastInterstitialAdTime = Date()
            }) {
                InterstitialContentView(isPresented: $isShowingInterstitialAd, navigationTitle: "Task Beacon")
            }
            .fullScreenCover(isPresented: Binding(
                get: { isScanning && AVCaptureDevice.authorizationStatus(for: .video) == .authorized },
                set: { isScanning = $0 }
            )) {
                BarcodeScannerView { barcode in
                    isScanning = false
                    barcodeScannerViewModel.fetchProductDetails(barcode: barcode, completion: { item in
                        if let item = item {
                            scannedItem = item
                            
                            Task {
                                var location: CLLocation?
                                if let userCoordinate = self.userLocation {
                                    location = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
                                }
                                
                                await locationManager.searchNearbyStores()
                                
                                await MainActor.run {
                                    mkMapItems = locationManager.stores
                                    showStoreSelectionSheet = true
                                }
                            }
                        } else {
                            showErrorMessage = "❌ Product not found."
                        }
                    })
                }
            }
            .sheet(isPresented: $showStoreSelectionSheet, onDismiss: {
                // In sheet onDismiss handler after updating the item and before calling the grouping function
                if shoppingListViewModel.emojiMap.isEmpty {
                    shoppingListViewModel.emojiMap = shoppingListViewModel.loadEmojiMap()
                }
                
                if let item = selectedShoppingItem, let store = selectedStore {
                    // Update the item with store information
                    item.storeName = storeName
                    item.storeAddress = storeAddress
                    
                    if let latitude = latitude, let longitude = longitude {
                        item.latitude = latitude
                        item.longitude = longitude
                    }
                    
                    if let item = selectedShoppingItem {
                        // Ensure emoji is set when assigning a store
                        if item.emoji == nil || item.emoji?.isEmpty == true {
                            // Make sure emoji map is loaded
                            if shoppingListViewModel.emojiMap.isEmpty {
                                shoppingListViewModel.emojiMap = shoppingListViewModel.loadEmojiMap()
                            }
                            
                            // Set emoji based on item name
                            let emoji = shoppingListViewModel.emojiForItemName(item.name ?? "")
                            item.emoji = emoji
                        }
                    }
                    
                    Task {
                        await shoppingListViewModel.saveShoppingItemToCoreData(item: item)
                        
                        // Update UI after saving
                        DispatchQueue.main.async {
                            self.refreshTrigger = UUID()
                            
                            // Auto-expand the new store/category
                            if let store = item.storeName, let category = item.category {
                                let key = "\(store)_\(category)"
                                self.expandedCategoryMap[key] = true
                                print("🔓 Auto-expanding category at \(key)")
                            }
                        }
                    }
                    
                    print("✅ Store assignment initiated for item: \(item.name ?? "Unknown")")
                    
                    // Reset states
                    selectedShoppingItem = nil
                    selectedStore = nil
                    
                    storeName = ""
                    storeAddress = ""
                    latitude = nil
                    longitude = nil
                }
            }) {
                MapView(
                    cameraPosition: .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(
                            latitude: latitude ?? 0.0,
                            longitude: longitude ?? 0.0
                        ),
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )),
                    mapIsForShoppingItem: true,
                    onLocationSelected: { coordinate, name, address in
                        latitude = coordinate.latitude
                        longitude = coordinate.longitude
                        storeName = name
                        storeAddress = address
                        
                        // Create a mock MKMapItem for the selected store to maintain consistency
                        let placemark = MKPlacemark(coordinate: coordinate)
                        let mapItem = MKMapItem(placemark: placemark)
                        mapItem.name = name
                        selectedStore = mapItem
                        
                        showStoreSelectionSheet = false
                    }
                )
                .environmentObject(locationManager)
                .environmentObject(shoppingListViewModel)
                
//                UnifiedStoreSelectionView(isPresented: $showStoreSelectionSheet,
//                                          selectedStoreFilter: $selectedStoreFilter,
//                                          storeName: $storeName,
//                                          storeAddress: $storeAddress,
//                                          selectedStore: $selectedStore,
//                                          latitude: $latitude,
//                                          longitude: $longitude,
//                                          isPreferred: $isPreferred
//                )
            }
            .fullScreenCover(isPresented: $isShowingAnySheet, onDismiss: {
                // Request a refresh when any sheet is dismissed, with a simpler approach
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Use a single refresh call instead of multiple redundant ones
                    self.refreshDataAndViews()
                    
                    // Check if the edited item now has a store assigned
                    self.handleStoreAssignment()
                }
                
                // Reset all sheet-related states when dismissed
                showAddShoppingItem = false
                showAddTodoItem = false
                showSettings = false
                isShowingAnySheet = false
            }) {
                CustomSheetView(
                    showAddShoppingItem: $showAddShoppingItem,
                    showAddTodoItem: $showAddTodoItem,
                    selectedShoppingItem: $selectedShoppingItem,
                    selectedToDoItem: $selectedToDoItem,
                    navigateToEditableList: $navigateToEditableList,
                    isShowingAnySheet: $isShowingAnySheet
                )
                .environmentObject(todoListViewModel)
                .environmentObject(shoppingListViewModel)
            }
            .sheet(isPresented: $showSettings) {
                NavigationView {
                    SettingsView()
                        .environmentObject(preferredStoreManager)
                        .environmentObject(subscriptionsManager)
                }
            }
            .onChange(of: appDelegate.adManager.isAdReady) {
                appDelegate.handleAdChange(appDelegate.adManager.isAdReady)
            }
            .onChange(of: shoppingListViewModel.shoppingItems) {
                checkForRewardedAdTrigger()
            }
            .onChange(of: todoListViewModel.toDoItems) {
                checkForRewardedAdTrigger()
            }
            .onAppear {
                observeChanges()
                
                // Force refresh data when view appears, but with slight delay to avoid race conditions
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.refreshDataAndViews()
                }
                             
                locationManager.loadAndMonitorAllGeofences(from: viewContext)
                
//                for item in shoppingListViewModel.shoppingItems {
//                    if let uid = item.uid, item.latitude != 0, item.longitude != 0 {
//                        let coordinate = CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)
//                        locationManager.monitorRegionAtLocation(center: coordinate, identifier: item.uid ?? UUID().uuidString, item: item)
//                    }
//                }
            }
            .onDisappear {
                print("♻️ Cleaned up resources in EditableListView")
            }
        }
        .onAppear {
            print("🔍 .onAppear triggered in EditableListView")

            setupOnAppear()
            
            checkForRewardedAdTrigger()
            
            startInterstitialAdTimer()
        }
        .onDisappear {
            adCheckTimer?.invalidate()
            adCheckTimer = nil
            print("♻️ Cleaned up resources in EditableListView")
        }
        .alert(permissionManager.permissionAlertTitle, isPresented: $permissionManager.showPermissionAlert) {
            Button("Open Settings") {
                permissionManager.openSettings()
            }
            
            Button(Constants.cancel, role: .cancel) {}
        } message: {
            Text(permissionManager.permissionAlertMessage)
        }
        // Add the alert modifier here, at the same level as onAppear
        .alert(permissionManager.permissionAlertTitle, isPresented: $permissionManager.showPermissionAlert) {
            Button("Open Settings") {
                permissionManager.openSettings()
            }
            Button(Constants.cancel, role: .cancel) {}
        } message: {
            Text(permissionManager.permissionAlertMessage)
        }
    }
        
    func startInterstitialAdTimer() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            if appDelegate.adManager.canShowInterstitialAd() && !isShowingInterstitialAd && !isShowingRewardedAd {
                preloadAndShowInterstitialAd()
            }
        }
    }
    
    private func preloadAndShowInterstitialAd() {
        // Create a temporary view model to test if ad can be loaded
        let tempViewModel = InterstitialViewModel()
        
        tempViewModel.loadAndShowAd(
            onDismissed: {
                // Ad was dismissed normally
            },
            onAdReady: {
                // Ad is ready, now show the sheet
                DispatchQueue.main.async {
                    self.isShowingInterstitialAd = true
                    self.appDelegate.adManager.lastInterstitialAdTime = Date()
                }
            },
            onAdFailed: {
                // Ad failed to load, don't show the sheet
                print("Interstitial ad failed to load, not showing sheet")
            }
        )
    }
    
    func checkForRewardedAdTrigger() {
        print("🔍 Checking if should show rewarded ad...")
        print("Is Premium User: \(entitlementManager.isPremiumUser)")
        print("Has Monthly Subscription: \(entitlementManager.hasMonthlySubscription)")
        print("Has Annual Subscription: \(entitlementManager.hasAnnualSubscription)")
        print("Should Show Rewarded Ad Section: \(shouldShowRewardedAdSection)")
        print("Is Over Free Limit: \(shoppingListViewModel.isOverFreeLimit())")
        print("Can Show Limit Extension Reward: \(appDelegate.adManager.canShowLimitExtensionReward())")
        
        // Add this debug line:
        print("�� EntitlementManager instance: \(entitlementManager)")
        print("�� EntitlementManager.shared instance: \(EntitlementManager.shared)")
        print("🔍 Are they the same? \(entitlementManager === EntitlementManager.shared)")

        if shoppingListViewModel.isOverFreeLimit() && appDelegate.adManager.canShowAd() && !isShowingRewardedAd {
            isShowingRewardedAd = true
            appDelegate.adManager.lastAdTime = Date()
        }
    }
    
    // Helper function for accessibility hint
    private func accessibilityHint(for item: ToDoItemEntity) -> String {
        var hints: [String] = []
        
        if let category = item.category, !category.isEmpty {
            hints.append("Category: \(category)")
        }
        
        if let dueDate = item.dueDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            hints.append("Due: \(dateFormatter.string(from: dueDate))")
        }
        
        if let location = item.addressOrLocationName, !location.isEmpty {
            hints.append("Location: \(location)")
        }
        
        return hints.joined(separator: ", ")
    }
    
    private func handleFlatMove(from source: IndexSet,
                                to destination: Int,
                                flatItems: [ToDoItemEntity],
                                flatRows: [ToDoRow]) {
        // Create a mutable copy of the items
        var items = flatItems
        
        // Get the source items and their indices in the flatItems array
        let sourceItems = source.map { index in
            if case .item(let item) = flatRows[index] {
                return item
            }
            return nil
        }.compactMap { $0 }
        
        // Find the actual indices in the flatItems array
        let sourceIndices = sourceItems.compactMap { item in
            items.firstIndex(where: { $0.objectID == item.objectID })
        }
        
        // Calculate the actual destination index in the flatItems array
        var actualDestination = destination
        var itemCount = 0
        for i in 0..<destination {
            if case .item = flatRows[i] {
                itemCount += 1
            }
        }
        actualDestination = itemCount
        
        // Move the items using the actual indices
        items.move(fromOffsets: IndexSet(sourceIndices), toOffset: actualDestination)
        
        // Find the new priority for each moved item
        for item in sourceItems {
            // Find the destination section by looking at the headers around the destination index
            var newPriority: Int16 = item.priority // Default to current priority
            
            // First, find the header that comes before the destination
            for i in (0..<destination).reversed() {
                if case .header(let priority) = flatRows[i] {
                    newPriority = priority.int16Value
                    break
                }
            }
            
            // Update the priority
            item.priority = newPriority
        }
        
        // Save all changes at once
        do {
            try viewContext.save()
            
            // Update the view model and force a refresh
            DispatchQueue.main.async {
                self.todoListViewModel.updateGroupedToDoItems(updateExists: true)
                self.refreshTrigger = UUID() // Force view refresh
            }
        } catch {
            print("Error saving context: \(error)")
        }
    }
        
    // Add this function to EditableListView:
    private func requestLocationIfNeeded() {
        print("🔍 Checking location permissions")
       // let locationManager = CLLocationManager()
        let status = locationManager.authorizationStatus
        
        if status == .notDetermined {
            print("📍 Requesting location permission")
            locationManager.requestAuthorization()
        } else if status == .denied || status == .restricted {
            print("⚠️ Location permission denied or restricted")
        } else {
            print("✅ Location permission already granted")
        }
    }
    
    // Call this function when preparing to show the store selection:
    private func showStoreSelection() {
        Task {
            if await permissionManager.checkAndRequestPermission(for: .location) {
                // Initialize store list before showing sheet
                if mkMapItems.isEmpty {
                    // Try to get location-based stores with a slight delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        Task { await self.locationManager.performDirectMapKitSearch() }
                        
                        self.showStoreSelectionSheet = true
                    }
                } else {
                    // We already have stores, just show the sheet
                    showStoreSelectionSheet = true
                }
            }
        }
    }
    
    // Reusable view for shopping items list
    @ViewBuilder
    private func shoppingItemsList(items: [ShoppingItemEntity]) -> some View {
        ForEach(items, id: \.objectID) { item in
            ZStack {
                Button(action: {
                    // Edit the item when tapped
                    selectedShoppingItem = item
                    
                    if ((item.storeName?.isEmpty) == nil) {
                        showStoreSelectionSheet = true
                    } else {
                        showAddShoppingItem = true
                        isShowingAnySheet = true
                    }
                }) {
                    ShoppingItemRow(item: item)
                        .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .listRowInsets(EdgeInsets())
            .padding(.vertical, 2)
            .background(Color(.systemBackground))
            .contextMenu {
                // Check if item has no store assigned (based on your ShoppingItemRow logic)
                let hasNoStore = item.storeName == nil || item.storeName?.isEmpty == true
                
                if hasNoStore {
                    Button(action: {
                        assignStoreToItem(item)
                    }) {
                        Label("Assign Store", systemImage: "mappin.circle")
                    }
                    
                    Button(action: {
                        selectedShoppingItem = item
                        showAddShoppingItem = true
                        isShowingAnySheet = true
                    }) {
                        Label("Edit Item", systemImage: "pencil")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        withAnimation {
                            deleteShoppingItem(item)
                        }
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    withAnimation {
                        deleteShoppingItem(item)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
        }
    }
    
    private func assignStoreToItem(_ item: ShoppingItemEntity) {
        print("🏪 Assigning store to item: \(item.name ?? "Unknown")")
        
        // Set the item for store assignment
        selectedShoppingItem = item
        
        // Show store selection sheet
        Task {
            if await permissionManager.checkAndRequestPermission(for: .location) {
                // Initialize store list before showing sheet
                if locationManager.stores.isEmpty {
                    // Try to get location-based stores with a slight delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        Task { await self.locationManager.performDirectMapKitSearch() }
                        self.showStoreSelectionSheet = true
                    }
                } else {
                    // We already have stores, just show the sheet
                    showStoreSelectionSheet = true
                }
            }
        }
    }

    private func removeStoreFromItem(_ item: ShoppingItemEntity) {
        print("🗑️ Removing store from item: \(item.name ?? "Unknown")")
        
        // Clear store information
        item.storeName = nil
        item.storeAddress = nil
        item.latitude = 0.0
        item.longitude = 0.0
        
        // Use the view model's save function
        Task {
            await shoppingListViewModel.saveShoppingItemToCoreData(item: item)
            
            // Update UI after saving
            DispatchQueue.main.async {
                self.refreshTrigger = UUID()
            }
        }
        
        print("✅ Store removal initiated for item: \(item.name ?? "Unknown")")
    }

    
    // Add this method to EditableListView
    private func deleteToDoItem(_ item: ToDoItemEntity) {
        if let locationIdentifier = item.value(forKey: "uid") as? String {
            // Use the existing view model function
            todoListViewModel.deleteToDoItem(item: item)
            
            // Set up undo functionality
            recentlyDeletedItem = (item, {
                // Restore the item if the user taps Undo
                let context = PersistenceController.shared.container.viewContext
                let newItem = ToDoItemEntity(context: context)
                newItem.uid = item.uid
                newItem.task = item.task
                newItem.category = item.category
                newItem.priority = item.priority
                newItem.dueDate = item.dueDate
                newItem.isCompleted = false
                newItem.lastEditor = Constants.emptyString
                newItem.lastUpdated = Date()
                newItem.latitude = 0.0
                newItem.longitude = 0.0
                
                // Save the restored item
                try? context.save()
                
                // Refresh the UI
                DispatchQueue.main.async {
                    self.todoListViewModel.updateGroupedToDoItems(updateExists: true)
                    self.refreshTrigger = UUID()
                }
            })
            
            // Automatically dismiss the undo button after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if self.recentlyDeletedItem?.0 === item {
                    self.recentlyDeletedItem = nil
                }
            }
            
            print("in deleteToDoitem locationIdentifier : \(locationIdentifier)")
            
            locationManager.checkAndUpdateRegionMonitoring(for: locationIdentifier)
        }
    }
    
    // Reusable view for category labels
    @ViewBuilder
    private func categoryLabel(category: String, items: [ShoppingItemEntity]) -> some View {
        HStack {
            let emoji = item(for: category)
            Text(items.first?.categoryEmoji ?? "✳️")
            Text(category)
                .foregroundColor(.primary)
            Spacer()
            Text("\(items.count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .cornerRadius(12)
        }
    }

    // Content for unassigned items categories
    @ViewBuilder
    private func unassignedItemsCategoriesContent(otherStore: String) -> some View {
        if let categories = shoppingListViewModel.groupedItemsByStoreAndCategory[otherStore] {
            ForEach(Array(categories.keys.sorted()), id: \.self) { category in
                if let items = categories[category], !items.isEmpty {
                    // Reuse the same category disclosure pattern
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedCategoryMap["\(otherStore)_\(category)"] ?? false },
                            set: { expandedCategoryMap["\(otherStore)_\(category)"] = $0 }
                        ),
                        content: {
                            shoppingItemsList(items: items)
                        },
                        label: {
                            categoryLabel(category: category, items: items)
                        }
                    )
                    .background(Color(.systemBackground))
                    .listRowBackground(Color(.systemBackground))
                }
            }
        }
    }
    
    // Helper function to set up on appear
    private func setupOnAppear() {
        print("🔍 setupOnAppear() called - starting permission checks")

        // Clear any existing store data to avoid defaults
        self.selectedStore = nil
        self.storeName = ""
        self.storeAddress = ""
        self.stores = []
        
        print("🔍 Starting store fetch for selection...")
        
        // Check all required permissions
        Task {
            print("🔍 About to check location permission...")

            // Check location permission
            if await permissionManager.checkAndRequestPermission(for: .location) {
                print("✅ Location permission granted")

                // Set up location manager delegate and request authorization
                setupUserLocationManager()
                
                // Initial direct search with location if available
                await locationManager.performDirectMapKitSearch()
            } else {
                print("❌ Location permission not granted")
            }
            
            // Check notification permission
            _ = await permissionManager.checkAndRequestPermission(for: .notifications)
        }
        
        // Only load subscription products - avoid other data loads
        Task { await subscriptionsManager.loadProducts() }
    }
    
    // Setup location manager with proper delegate pattern
    private func setupUserLocationManager() {
        // Set up delegate
        LocationManager.shared.onLocationUpdate = { coordinate in
            // Update userLocation state and trigger UI update
            DispatchQueue.main.async {
                self.userLocation = coordinate
                print("📍 USER LOCATION UPDATED: \(coordinate.latitude), \(coordinate.longitude)")
                
                // If we haven't found stores yet, try searching now that we have location
                if LocationManager.shared.stores.isEmpty == true {
                    Task {
                        await LocationManager.shared.performDirectMapKitSearch()
                    }
                }
            }
        }
        
        LocationManager.shared.onAuthStatusChange = { status in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                print("🔐 Location access granted")
                // Search now that we have authorization
              //  LocationManager.shared.locationManager.requestLocation() // Use shared instance instead of manager
            case .denied, .restricted:
                print("🔐 Location access denied, using default Utah location")
                // Fallback to known Utah coordinates instead of San Francisco
                self.userLocation = CLLocationCoordinate2D(latitude: 0, longitude: 0)
                Task { await LocationManager.shared.performDirectMapKitSearch() }
            case .notDetermined:
                print("🔐 Location access not determined yet, requesting")
                LocationManager.shared.requestAuthorization() // Use shared instance instead of manager
            @unknown default:
                print("🔐 Unknown location authorization status")
                // Fallback to known Utah coordinates
                self.userLocation = CLLocationCoordinate2D(latitude: 0, longitude: 0)
                Task { await LocationManager.shared.performDirectMapKitSearch() }
            }
        }
    }
    
    private func observeChanges() {
        DispatchQueue.main.async {
            handleSceneChange(scenePhase)
            
            if let quickAction = quickActionManager.quickAction {
                handleQuickActionChange(quickAction)
            }
            
            handleSegmentChange(selectedSegment)
        }
    }
    
    private func handleQAData() {
        if quickActionManager.quickAction == .isAddingToDoItem {
            showAddTodoItem = true
        } else if quickActionManager.quickAction == .isAddingShoppingItem {
            showAddShoppingItem = true
        } else if quickActionManager.quickAction == .isUpcomingToDoItem {
            
        }
    }
    
    private func handleSceneChange(_ phase: ScenePhase) {
        if phase == .background {
            print("🏠 App moved to background")
            appDelegate.showAd = false
        } else if phase == .active {
            // Remove the 2-second delay and check immediately
            print("🔔 App is active, checking if ad is ready")
            if appDelegate.adManager.isAdReady {
                print("✅ Ad is ready, but will not auto-run")
            }
        }
    }
    
    private func handleQuickActionChange(_ quickAction: QuickAction) {
        handleQAData() // Call existing function
    }
    
    private func handleSegmentChange(_ segment: String) {
        if segment == "Shopping" {
            shoppingListViewModel.updateGroupedItemsByStoreAndCategory(updateExists: true)
        } else {
            todoListViewModel.updateGroupedToDoItems(updateExists: true)
        }
    }
    
    private func dataFound() -> Bool {
        return !todoListViewModel.toDoItems.isEmpty || !shoppingListViewModel.shoppingItems.isEmpty
    }
    
    // ✅ Async method for handling segment changes
    private func switchItemType() {
        if selectedSegment == "Shopping" {
            dataUpdateManager.needsRefresh = false
            shoppingListViewModel.updateGroupedItemsByStoreAndCategory(updateExists: true)
        } else {
            dataUpdateManager.needsRefresh = false
            todoListViewModel.updateGroupedToDoItems(updateExists: true)
        }
    }
    
    private func getDepartment(for subcategory: String) -> String {
        for (department, subcategories) in Constants.departmentCategories {
            if subcategories.contains(subcategory) {
                return department
            }
        }
        return "Other"
    }
    
    // Modified refreshDataAndViews method with simpler but more direct approach
    private func refreshDataAndViews() {
        print("🔄 FULL REFRESH: Starting comprehensive refresh...")
        
        // First, fetch directly from Core Data
        do {
            let context = PersistenceController.shared.container.viewContext
            let request = NSFetchRequest<ShoppingItemEntity>(entityName: CoreDataEntities.shoppingItem.stringValue)
            let items = try context.fetch(request)
            
            print("📦 Core Data contains \(items.count) items")
            
            // Update on main thread with simpler but more direct approach
            DispatchQueue.main.async {
                // Reset view state
                self.unassignedItemsExpanded = false
                
                // Update the view model data
                self.shoppingListViewModel.shoppingItems = items
                
                // Clear and rebuild the groupings
                self.shoppingListViewModel.groupedItemsByStoreAndCategory.removeAll()
                self.shoppingListViewModel.updateGroupedItemsByStoreAndCategory(updateExists: true)
                
                // Force view refresh immediately
                self.refreshTrigger = UUID()
                
                // Schedule another refresh after a delay to handle any animations
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔄 Performing follow-up refresh...")
                    self.refreshTrigger = UUID()
                }
            }
        } catch {
            print("❌ Error fetching from Core Data: \(error.localizedDescription)")
        }
    }
    
    // Add a method to handle store assignment updates
    private func handleStoreAssignment() {
        // If an item was selected for editing and has a store assigned, refresh the view
        if let item = selectedShoppingItem, !(item.storeName?.isEmpty ?? true) {
            // Update state directly without using notifications
            DispatchQueue.main.async {
                print("⚙️ Store assignment handling for item: \(item.name ?? "unknown")")
                
                // First make sure the item isn't shown in the unassigned list
                unassignedItemsExpanded = false
                
                // Create key for the new store and category to expand it
                if let store = item.storeName, let category = item.category {
                    let key = "\(store)_\(category)"
                    expandedCategoryMap[key] = true
                    print("🔓 Auto-expanding category at \(key)")
                }
                
                // Force a clean refresh that gets data directly from Core Data
                refreshDataAndViews()
                
                // Force UI redraw with our local trigger
                refreshTrigger = UUID()
                
                // Log debug info
                print("🔄 Store Assignment - Item \(item.name ?? "unknown") assigned to \(item.storeName ?? "unknown")")
                print("📊 Current item count: \(shoppingListViewModel.shoppingItems.count)")
                print("🏬 Current stores: \(shoppingListViewModel.groupedItemsByStoreAndCategory.keys.joined(separator: ", "))")
            }
        }
    }
    
    // Method to delete a shopping item
    private func deleteShoppingItem(_ item: ShoppingItemEntity) {
        // Use the view model to handle the deletion
        shoppingListViewModel.deleteShoppingItem(item: item)
        
        // Set up undo functionality
        recentlyDeletedItem = (item, {
            // Restore the item if the user taps Undo
            let context = PersistenceController.shared.container.viewContext
            let newItem = ShoppingItemEntity(context: context)
            newItem.uid = item.uid
            newItem.name = item.name
            newItem.category = item.category
            newItem.storeName = item.storeName
            newItem.storeAddress = item.storeAddress
            newItem.lastUpdated = Date()
            newItem.dateAdded = item.dateAdded
            newItem.isPreferred = item.isPreferred
            
            // Save the restored item
            try? context.save()
            
            // Refresh the UI
            DispatchQueue.main.async {
                self.refreshDataAndViews()
            }
        })
        
        // Automatically dismiss the undo button after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.recentlyDeletedItem?.0 === item {
                self.recentlyDeletedItem = nil
            }
        }
        
        print("in deleteShoppingItem")
        if let locationIdentifier = item.value(forKey: "storeAddress") as? String {
            print("in deleteShoppingItem locationIdentifier : \(locationIdentifier)")

            locationManager.checkAndUpdateRegionMonitoring(for: locationIdentifier)
        }
    }
    
    // Method to get emoji for a category
    private func item(for category: String) -> String {
        // Get emoji from shopping list view model if available
        if let emoji = shoppingListViewModel.emojiMap[category] {
            return emoji
        }
        
        // Fallback emojis for common categories
        switch category.lowercased() {
        case "produce", "fruits", "vegetables":
            return "🥦"
        case "dairy", "milk", "cheese":
            return "🥛"
        case "meat", "poultry", "seafood":
            return "🥩"
        case "bakery", "bread", "baked goods":
            return "🍞"
        case "snacks", "chips", "crackers":
            return "🍿"
        case "beverages", "drinks", "soda":
            return "🥤"
        case "cleaning", "household":
            return "🧹"
        case "personal care", "health", "beauty":
            return "🧴"
        case "pantry", "canned goods", "dry goods":
            return "🥫"
        case "pet", "pet food", "pet supplies":
            return "🐾"
        case "baby", "baby care":
            return "👶"
        case "electronics":
            return "📱"
        case "clothing", "apparel":
            return "👕"
        case "uncategorized":
            return "📦"
        default:
            return "🛒"
        }
    }
    
    // Helper to determine the category of a product for barcode scanning
    private func determineCategory(for productName: String, apiCategory: String?) -> String {
        // First try to use the API category if available
        if let category = apiCategory, !category.isEmpty {
            return category
        }
        
        // Fallback logic to determine category from product name
        let name = productName.lowercased()
        
        if name.contains("milk") || name.contains("cheese") || name.contains("yogurt") || name.contains("butter") {
            return "Dairy"
        } else if name.contains("bread") || name.contains("bagel") || name.contains("muffin") || name.contains("pastry") {
            return "Bakery"
        } else if name.contains("apple") || name.contains("banana") || name.contains("orange") || name.contains("fruit") {
            return "Produce"
        } else if name.contains("chicken") || name.contains("beef") || name.contains("pork") || name.contains("meat") {
            return "Meat"
        } else if name.contains("pasta") || name.contains("rice") || name.contains("cereal") || name.contains("flour") {
            return "Pantry"
        } else if name.contains("soda") || name.contains("water") || name.contains("juice") || name.contains("drink") {
            return "Beverages"
        } else if name.contains("cookie") || name.contains("chip") || name.contains("cracker") || name.contains("snack") {
            return "Snacks"
        } else if name.contains("soap") || name.contains("shampoo") || name.contains("toothpaste") {
            return "Personal Care"
        } else if name.contains("cleaner") || name.contains("detergent") || name.contains("paper towel") {
            return "Cleaning"
        }
        
        // Default category if nothing else matches
        return "Uncategorized"
    }
    
    // Add this function to handle store selection sheet dismissal
    private func handleStoreSelectionDismissal() {
        // Immediately refresh the UI with the most comprehensive refresh
        print("🔄 Store selection sheet dismissed - refreshing views")
        
        // First perform a thorough refresh to get latest data from Core Data
        self.refreshDataAndViews()
        
        // Check if the edited item now has a store assigned
        if let item = scannedItem, !(item.storeName?.isEmpty ?? true) {
            print("🛒 Item \(item.name ?? "Unknown") assigned to \(item.storeName ?? "Unknown")")
            
            // Track last store assignment time
            lastStoreAssignmentTime = Date()
            
            // Toggle force update state to trigger view refresh
            self.forceViewUpdate.toggle()
            
            // Close the unassigned items disclosure group
            unassignedItemsExpanded = false
            
            // Store the destination category & store to auto-expand it
            if let store = item.storeName, let category = item.category {
                let key = "\(store)_\(category)"
                expandedCategoryMap[key] = true
                print("🔓 Auto-expanding newly assigned item at \(key)")
                
                // Force UI update
                withAnimation {
                    refreshTrigger = UUID()
                }
            }
            
            // Reset scanned item to avoid stale references
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.scannedItem = nil
            }
        }
    }
    
    // Add this method to handle MapKit throttling
    private func handleMapKitThrottle(timeUntilReset: Int) {
        isThrottled = true
        throttleResetTime = timeUntilReset
        throttleErrorMessage = "MapKit search limit reached. Please wait \(timeUntilReset) seconds."
        
        // Create a timer to count down and update the message
        throttleTimer?.invalidate()
        throttleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if throttleResetTime > 0 {
                throttleResetTime -= 1
                throttleErrorMessage = "MapKit search limit reached. Please wait \(throttleResetTime) seconds."
            } else {
                isThrottled = false
                throttleErrorMessage = nil
                timer.invalidate()
                throttleTimer = nil
            }
        }
    }
}

// Add this loading view component
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.9)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(2.0)  // Increased from 1.5
                    .tint(.accentColor)
                    .padding()
                    .background(
                        Circle()
                            .fill(Color(.systemBackground))
                            .shadow(radius: 5)
                    )
                
                Text("Loading Stores...")
                    .font(.title2)  // Increased from headline
                    .fontWeight(.bold)  // Added bold
                    .foregroundColor(.primary)
                
                Text("Finding stores near your location")
                    .font(.headline)  // Increased from subheadline
                    .foregroundColor(.secondary)
            }
            .padding(30)  // Increased padding
            .background(
                RoundedRectangle(cornerRadius: 20)  // Increased corner radius
                    .fill(Color(.systemBackground))
                    .shadow(radius: 15)  // Increased shadow
            )
        }
        .transition(.opacity)
    }
}

// Add this modifier to keep the animation code separate and reusable
struct PulseAnimation: ViewModifier {
    var isPulsing: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .scaleEffect(isPulsing ? 1.1 : 0.95)
            )
    }
}

// Section Header Views
private struct PrioritySectionHeader: View {
    @Environment(\.colorScheme) var colorScheme
    let priority: Priority
    let itemCount: Int
    
    var body: some View {
        HStack {
            Text(priority.title)
                .font(.headline)
                .foregroundColor(priorityColor(for: priority.int16Value, colorScheme: colorScheme))
        }
    }
}

private struct CategorySectionHeader: View {
    let category: String
    let itemCount: Int
    
    var body: some View {
        HStack {
            Text(category)
                .font(.headline)
                .foregroundColor(.primary)
            
//            Spacer()
//            
//            Text("\(itemCount)")
//                .font(.caption)
//                .foregroundColor(.secondary)
//                .padding(.horizontal, 8)
//                .padding(.vertical, 4)
//                .background(Color(.systemGray5))
//                .cornerRadius(12)
        }
    }
}

private struct EmptyItemsView: View {
    var body: some View {
        Text("No items")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color(.systemGray6))
            .font(.footnote)
            .padding(.vertical, 2)
    }
}



