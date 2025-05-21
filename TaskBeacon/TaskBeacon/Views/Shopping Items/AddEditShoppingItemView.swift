//
//  AddShoppingItemView.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/5/25.
//

import CoreData
import CoreLocation
@preconcurrency import MapKit
import StoreKit
import SwiftUI

struct AddEditShoppingItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
            
    @EnvironmentObject var dataUpdateManager: DataUpdateManager
    @EnvironmentObject var viewModel: ShoppingListViewModel
    @EnvironmentObject var subscriptionsManager: SubscriptionsManager
    @EnvironmentObject var entitlementManager: EntitlementManager
    @EnvironmentObject var locationManager: LocationManager

    @State private var userLocation: CLLocationCoordinate2D?
    @State private var name: String = Constants.emptyString
    @State private var storeName: String = Constants.emptyString
    @State private var storeAddress: String = Constants.emptyString
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var selectedCategory: String = Constants.emptyString
    @State private var selectedCategoryEmoji: String = Constants.emptyString
    @State private var selectedStore: MKMapItem?
    @State private var showStoreSelection = false
    @State private var shoppingItem: ShoppingItemEntity?
    @State private var showStoreDetails = true
    @State private var forceRefresh = false
    @State private var nearbyStores: [StoreOption] = []
    @State private var expirationDate: Date = Date()
    @State private var showExpirationDatePicker = false
    @State private var selectedCategoryFromGroceryFood = false
    @State private var showSubscriptionSheet = false
    @State private var searchText = ""  // Add search field state
    @State private var isEditingText = false
    @State private var selectedStoreFilter: String = Constants.allStores
    @State private var hasLoadedProducts = false
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    @Binding var showAddShoppingItem: Bool
    @Binding var isShowingAnySheet: Bool
    @Binding var navigateToEditableList: Bool
    
    private let freeItemLimit = 5
    
    // In AddEditShoppingItemView.swift
    private var isOverFreeLimit: Bool {
        guard !entitlementManager.isPremiumUser else { return false }
        guard shoppingItem == nil else { return false } // Allow editing existing items
        
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

    init(navigateToEditableList: Binding<Bool>,
         showAddShoppingItem: Binding<Bool>,
         isShowingAnySheet: Binding<Bool>,
         shoppingItem: ShoppingItemEntity? = nil) {
        
        // Initialize bindings
        self._navigateToEditableList = navigateToEditableList
        self._showAddShoppingItem = showAddShoppingItem
        self._isShowingAnySheet = isShowingAnySheet
        self._shoppingItem = State(initialValue: shoppingItem)
        
        // Initialize state with existing values if editing
        if let shoppingItem = shoppingItem {
            _name = State(initialValue: shoppingItem.name ?? Constants.emptyString)
            _storeName = State(initialValue: shoppingItem.storeName ?? Constants.emptyString)
            _storeAddress = State(initialValue: shoppingItem.storeAddress ?? Constants.emptyString)
            _selectedCategory = State(initialValue: shoppingItem.category ?? Constants.emptyString)
            _expirationDate = State(initialValue: shoppingItem.expirationDate ?? Date())
            _showExpirationDatePicker = State(initialValue: shoppingItem.expirationDate == nil && Constants.perishableCategories.contains(shoppingItem.category ?? ""))
            
            // Set map region if coordinates exist
            if shoppingItem.latitude != 0 && shoppingItem.longitude != 0 {
                _mapRegion = State(initialValue: MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: shoppingItem.latitude, longitude: shoppingItem.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
        } else {
            _name = State(initialValue: Constants.emptyString)
            _storeName = State(initialValue: Constants.emptyString)
            _storeAddress = State(initialValue: Constants.emptyString)
            _selectedCategory = State(initialValue: Constants.emptyString)
            _expirationDate = State(initialValue: Date())
            _showExpirationDatePicker = State(initialValue: false)
        }
    }
    
    private var canSave: Bool {
        guard !name.isEmpty, !selectedCategory.isEmpty else { return false }
        return true
    }
    
    // MARK: - Main View Body
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        if isOverFreeLimit {
                            FreeUserLimitView(
                                showSubscriptionSheet: $showSubscriptionSheet
                            )
                        }

                        // Item Name Section
                        ItemNameSection(name: $name, isEditingText: $isEditingText)
                        
                        // Expiration Date Section (conditional)
                        if Constants.perishableCategories.contains(selectedCategory) {
                            ExpirationDateSection(expirationDate: $expirationDate,
                                                  showDatePicker: showExpirationDatePicker,
                                                  selectedCategory: selectedCategory,
                                                  item: name)
                        }

                        // Category Picker Section
                        CategoryPickerSection(selectedCategoryEmoji: $selectedCategoryEmoji,
                            selectedCategory: $selectedCategory,
                                              selectedCategoryFromGroceryFood: $selectedCategoryFromGroceryFood)

                        // Store Picker Section
                        StorePickerSection(storeName: $storeName,
                            storeAddress: $storeAddress,
                            showStoreDetails: $showStoreDetails,
                            showStoreSelection: $showStoreSelection,
                                           selectedStore: $selectedStore,
                                           isEditingText: $isEditingText,
                                           locationManager: locationManager)
                    }
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("New Shopping Item")
            .navigationBarItems(
                leading: Button(Constants.cancel) {
                    dismissSheet()
                },
                trailing: Button(Constants.save) {
                    Task {
                        await saveShoppingItem()
                        dismissSheet()
                    }
                }
                .disabled(!canSave || isOverFreeLimit)
            )
            .onAppear {
                setupOnAppear()
            }
            // Store Selection Sheet
            // In AddEditShoppingItemView
            .sheet(isPresented: $showStoreSelection, onDismiss: {
                isEditingText = false
            }) {
                // Create a temporary wrapper view that forces store load on appear
                ZStack {
                    Color.clear.onAppear {
                        print("Store sheet appearing, force loading fresh stores...")
                        // Force refresh any state before loading real view
                        Task {
                            // Force refresh stores when presenting view
                            if self.locationManager.stores.isEmpty {
                                await self.locationManager.performDirectMapKitSearch()
                            }
                            // Trigger a state update to force refresh
                            await MainActor.run {
                                self.forceRefresh.toggle()
                            }
                        }
                    }
                    
                    UnifiedStoreSelectionView(isPresented: $showStoreSelection,
                                             selectedStoreFilter: $selectedStoreFilter,
                                             storeName: $storeName,
                                             storeAddress: $storeAddress,
                                             selectedStore: $selectedStore,
                                             latitude: $latitude,
                                             longitude: $longitude)
                }
            }
            .sheet(isPresented: $showSubscriptionSheet) {
                SubscriptionScreen(showSubscriptionScreen: $showSubscriptionSheet)
                    .environmentObject(subscriptionsManager)
                    .environmentObject(entitlementManager)
            }
        }
    }

    private struct ItemNameSection: View {
        @Binding var name: String
        @Binding var isEditingText: Bool
        
        var body: some View {
            RoundedSectionBackground(title: "Item Name", iconName: "pencil") {
                TextField("Item Name", text: $name)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .padding()
                    .onTapGesture {
                        // Force UI updates to happen immediately on tap
                        DispatchQueue.main.async {
                            self.isEditingText = true
                        }
                    }
            }
            .transition(.opacity)
            .animation(.easeInOut, value: true)
        }
    }
    
    struct ExpirationDateSection: View {
        @EnvironmentObject var viewModel: ShoppingListViewModel

        @Binding var expirationDate: Date

        @State private var showDatePicker: Bool = false
        
        var selectedCategory: String
        
        let item: String
        
        init(expirationDate: Binding<Date>,
             showDatePicker: Bool,
             selectedCategory: String,
             item: String) {
            self._expirationDate = expirationDate
            self.showDatePicker = showDatePicker
            self.selectedCategory = selectedCategory
            self.item = item
        }
        
        var body: some View {
            RoundedSectionBackground(title: "Expiration Date", iconName: "calendar",
                                     expirationEstimate: viewModel.getEstimatedExpirationDate(for: selectedCategory, item: item)) {
                VStack(alignment: .leading, spacing: 12) {
                    // Toggle for custom date
                    Toggle("Change Estimated Date", isOn: $showDatePicker)
                        .padding(.horizontal)
                        .padding(.top, 5)
                    
                    // Show date picker if toggle is on
                    if showDatePicker {
                        DatePicker("Set Expiration Date",
                                 selection: $expirationDate,
                                 displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding()
                    }
                }
            }
            .transition(.scale)
            .animation(.spring(), value: true)
        }
    }
    
    // Helper function to set up on appear
    private func setupOnAppear() {
        // Only clear store data if we're adding a new item
        if shoppingItem == nil {
            self.selectedStore = nil
            self.storeName = ""
            self.storeAddress = ""
        }
        
        // Only perform initial search if stores are empty
        if locationManager.stores.isEmpty {
            Task {
                await self.locationManager.performDirectMapKitSearch()
            }
        }
        
        // Only load subscription products if not already loaded
        if !hasLoadedProducts {
            Task {
                await subscriptionsManager.loadProducts()
                hasLoadedProducts = true
            }
        }
    }

    private func dismissSheet() {
        showAddShoppingItem = false
        isShowingAnySheet = false
        presentationMode.wrappedValue.dismiss()
    }
    
    private func saveShoppingItem() async {
        do {
            // Check if this is a store assignment
            let isStoreAssignment = !storeName.isEmpty

            // CRITICAL: All Core Data operations need to happen on the main thread
            await MainActor.run {
                do {
                    // First, create or update the shopping item entity
                    var uid: String = Constants.emptyString
                    
                    let itemToSave: ShoppingItemEntity
                    
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
                        // Make sure emoji map is loaded
                        if viewModel.emojiMap.isEmpty {
                            viewModel.emojiMap = viewModel.loadEmojiMap()
                        }
                        
                        // Get emoji from name or category
                        let emojiFromName = viewModel.emojiForItemName(itemToSave.name ?? "")
                        itemToSave.emoji = emojiFromName
                        itemToSave.categoryEmoji = selectedCategoryEmoji
                    }
                    
                    // Now save the context
                    try viewContext.save()
                    
                    // Immediately fetch fresh data (still on main thread)
                    do {
                        let fetchRequest = NSFetchRequest<ShoppingItemEntity>(entityName: CoreDataEntities.shoppingItem.stringValue)
                        let items = try self.viewContext.fetch(fetchRequest)
                        
                        // If this was a store assignment, clear the grouping dictionary to force rebuild
                        if isStoreAssignment {
                            self.storeName = ""
                            self.storeAddress = ""
                            self.selectedStore = nil
                            self.latitude = nil
                            self.longitude = nil
                        }
                        
                        // Update grouping without triggering more fetches
                        viewModel.updateGroupedItemsInternal()
                        
                        if let uid = itemToSave.uid {
                            locationManager.monitorRegionAtLocation(center: CLLocationCoordinate2D(latitude: itemToSave.latitude, longitude: itemToSave.longitude), identifier: uid)
                            
                            locationManager.regionIDToItemMap[uid] = itemToSave
                        }
                        
                        // Update view model state directly
                        viewModel.objectWillChange.send()
                        
                        // Dismiss the sheet after saving is complete
                        dismissSheet()
                        
                    } catch {
                        print("❌ Error fetching updated items: \(error.localizedDescription)")
                    }
                } catch {
                    print("❌ Error saving to Core Data on main thread: \(error.localizedDescription)")
                }
            }
        }
    }

    // Setup location manager with proper delegate pattern
    private func setupUserLocationManager() {
        // Set up delegate
        locationManager.onLocationUpdate = { coordinate in
            // Update userLocation state and trigger UI update
            DispatchQueue.main.async {
                self.userLocation = coordinate
                
                // If we haven't found stores yet, try searching now that we have location
                if locationManager.stores.isEmpty {
                    Task {
                        await locationManager.performDirectMapKitSearch()
                    }
                }
            }
        }
    }

    // Get store categories
    private func getStoreCategories(from categorizedStores: [String: [MKMapItem]], filterBy category: String?) -> [String] {
        if let category = category {
            return categorizedStores.keys.filter { $0 == category }.sorted()
        } else {
            return categorizedStores.keys.sorted()
        }
    }
}

#if DEBUG
struct AddEditShoppingItemView_Previews: PreviewProvider {
    static var previews: some View {
        let navigateBinding = Binding.constant(false)
        let showAddBinding = Binding.constant(false)
        let isShowingAnySheetBinding = Binding.constant(false)
        
        return AddEditShoppingItemView(
            navigateToEditableList: navigateBinding,
            showAddShoppingItem: showAddBinding,
            isShowingAnySheet: isShowingAnySheetBinding
        )
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
#endif
