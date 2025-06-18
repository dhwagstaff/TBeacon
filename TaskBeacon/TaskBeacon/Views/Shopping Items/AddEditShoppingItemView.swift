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
    @State private var isPreferred = false
    @State private var selectedStoreFilter: String = Constants.allStores
    @State private var hasLoadedProducts = false
    @State private var isShowingRewardedAd = false
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    @FocusState private var isNameFocused: Bool // New focus state
    
    @Binding var showAddShoppingItem: Bool
    @Binding var isShowingAnySheet: Bool
    @Binding var navigateToEditableList: Bool
    
    let isEditingExistingItem: Bool
    
    private var canSave: Bool {
        guard !name.isEmpty, !selectedCategory.isEmpty else { return false }
        return true
    }

    init(navigateToEditableList: Binding<Bool>,
         showAddShoppingItem: Binding<Bool>,
         isShowingAnySheet: Binding<Bool>,
         isEditingExistingItem: Bool,
         shoppingItem: ShoppingItemEntity? = nil
    ) {
        // Initialize bindings
        self._navigateToEditableList = navigateToEditableList
        self._showAddShoppingItem = showAddShoppingItem
        self._isShowingAnySheet = isShowingAnySheet
        
        self.isEditingExistingItem = isEditingExistingItem
        
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
    
    // MARK: - Main View Body
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        if viewModel.isOverFreeLimit(isEditingExistingItem: isEditingExistingItem) {
                            FreeUserLimitView(
                                showSubscriptionSheet: $showSubscriptionSheet,
                                showRewardedAd: $isShowingRewardedAd
                            )
                        }

                        // Item Name Section
                        ItemNameSection(name: $name, isEditingText: $isEditingText)
                            .focused($isNameFocused)
                        
                        // Expiration Date Section (conditional)
                        if Constants.perishableCategories.contains(selectedCategory) {
                            ExpirationDateSection(expirationDate: $expirationDate,
                                                  showDatePicker: showExpirationDatePicker,
                                                  selectedCategory: selectedCategory,
                                                  item: name)
                        }

                        // Category Picker Section
                        ZStack {
                            CategoryPickerSection(selectedCategoryEmoji: $selectedCategoryEmoji,
                                                 selectedCategory: $selectedCategory,
                                                 selectedCategoryFromGroceryFood: $selectedCategoryFromGroceryFood)
                        }
                        .simultaneousGesture(TapGesture().onEnded { _ in
                            isNameFocused = false // Dismiss keyboard
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) // Force keyboard dismissal
                        })

                        // Store Picker Section
                        StorePickerSection(storeName: $storeName,
                            storeAddress: $storeAddress,
                            showStoreDetails: $showStoreDetails,
                            showStoreSelection: $showStoreSelection,
                                           selectedStore: $selectedStore,
                                           isEditingText: $isEditingText,
                                           locationManager: locationManager)
                    }
                    .sheet(isPresented: $isShowingRewardedAd) {
                        RewardedInterstitialContentView(
                            isPresented: $isShowingRewardedAd,
                            navigationTitle: "Task Beacon"
                        )
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
                        await viewModel.saveShoppingItem(storeName: storeName,
                                                         shoppingItem: shoppingItem,
                                                         name: name,
                                                         selectedCategory: selectedCategory,
                                                         storeAddress: storeAddress,
                                                         latitude: latitude,
                                                         longitude: longitude,
                                                         expirationDate: expirationDate,
                                                         selectedCategoryEmoji: selectedCategoryEmoji,
                                                         isPreferred: isPreferred)
                        storeName = Constants.emptyString
                        storeAddress = Constants.emptyString
                        selectedStore = nil
                        latitude = nil
                        longitude = nil
                    
                        dismissSheet()
                    }
                }
                .disabled(!canSave || viewModel.isOverFreeLimit())
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
                                              longitude: $longitude,
                                              isPreferred: $isPreferred,
                                              selectedShoppingItem: nil)
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

//struct AddEditShoppingItemView_Previews: PreviewProvider {
//    static var previews: some View {
//        let navigateBinding = Binding.constant(false)
//        let showAddBinding = Binding.constant(false)
//        let isShowingAnySheetBinding = Binding.constant(false)
//        
//        return AddEditShoppingItemView(
//            navigateToEditableList: navigateBinding,
//            showAddShoppingItem: showAddBinding,
//            isShowingAnySheet: isShowingAnySheetBinding
//        )
//        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
//    }
//}
