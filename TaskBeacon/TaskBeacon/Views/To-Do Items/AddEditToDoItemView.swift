//
//  AddToDoItemView.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/5/25.
//

import CoreData
import CoreLocation
import MapKit
import SwiftUI
import UserNotifications

struct AddEditToDoItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    @EnvironmentObject private var dataUpdateManager: DataUpdateManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var viewModel: ToDoListViewModel
    @EnvironmentObject var subscriptionsManager: SubscriptionsManager
    @EnvironmentObject var entitlementManager: EntitlementManager
    
    @State private var address = ""
    @State private var searchQuery = ""  // New state for the search query
    @State private var taskName: String = ""
    @State private var addressOrLocationName: String = ""
    @State private var latitude: Double? = 0
    @State private var longitude: Double? = 0
    @State private var needsLocation = false
    @State private var showMapPicker = false
    @State private var selectedCategory: String = "Uncategorized Item"
    @State private var dueDate = Date()
    @State private var customCategory: String = ""
    @State private var toDoItem: ToDoItemEntity?
    @State private var priority: Int16 = 2
    @State private var showCategorySelection = false
    @State private var showDatePicker = false
    @State private var showSubscriptionSheet = false
    @State private var locationData = LocationData(searchQuery: "", formattedAddress: "")
    @State private var didSaveLocation = false
    @State private var locationSelectedFromSearch = false
    
    @Binding var showAddTodoItem: Bool
    @Binding var isShowingAnySheet: Bool
    @Binding var navigateToEditableList: Bool
    
    private var storeNameBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedLocationName },
            set: { viewModel.selectedLocationName = $0 }
        )
    }

    private var storeAddressBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedLocationAddress },
            set: { viewModel.selectedLocationAddress = $0 }
        )
    }
    
    // In AddEditToDoItemView.swift
    private var isOverFreeLimit: Bool {
        FreeLimitChecker.isOverFreeLimit(
            isPremiumUser: entitlementManager.isPremiumUser,
            isEditingExistingItem: toDoItem != nil
        )
    }

    init(toDoItem: ToDoItemEntity? = nil,
         showAddTodoItem: Binding<Bool>,
         isShowingAnySheet: Binding<Bool>,
         navigateToEditableList: Binding<Bool>) {
        // Initialize Entitlement and Subscription Managers
        let entitlementManager = EntitlementManager()
        let subscriptionsManager = SubscriptionsManager(entitlementManager: entitlementManager)

        self._showAddTodoItem = showAddTodoItem
        self._isShowingAnySheet = isShowingAnySheet
        self._navigateToEditableList = navigateToEditableList
        self._toDoItem = State(initialValue: toDoItem)

        _taskName = State(initialValue: toDoItem?.task ?? "")
        _dueDate = State(initialValue: toDoItem?.dueDate ?? Date())
        _priority = State(initialValue: toDoItem?.priority ?? 2)
        _addressOrLocationName = State(initialValue: toDoItem?.addressOrLocationName ?? "")
        
        if let lat = toDoItem?.latitude, let lon = toDoItem?.longitude {
            _latitude = State(initialValue: lat)
            _longitude = State(initialValue: lon)
        } else {
            _latitude = State(initialValue: LocationManager.shared.userLocation?.coordinate.latitude ?? 0.0)
            _longitude = State(initialValue: LocationManager.shared.userLocation?.coordinate.longitude ?? 0.0)
        }

        _needsLocation = State(initialValue: toDoItem?.latitude != nil && toDoItem?.longitude != nil)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)

                Form {
                    if isOverFreeLimit {
                        Section {
                            FreeUserLimitView(showSubscriptionSheet: $showSubscriptionSheet)
                        }
                        .padding(.vertical, 16)
                    }
                    
                    TextField("Task Name", text: $taskName)
                        .foregroundColor(.primary)

                    PriorityPickerView(selectedPriority: $priority)
                    
                    Section(header: Text("Due Date")) {
                        Toggle("Item Needs Due Date", isOn: $showDatePicker)
                    }

                    if showDatePicker {
                        DatePicker("Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }

                    Section(header: Text("Category").foregroundColor(.primary)) {
                        Button(action: { showCategorySelection = true }) {
                            HStack {
                                Image(systemName: Constants.toDoCategoryIcons[selectedCategory] ?? "tag.fill")
                                    .foregroundColor(Constants.toDoCategoryColors[selectedCategory] ?? .gray)
                                Text(selectedCategory.isEmpty ? Constants.selectCategory : selectedCategory)
                                    .foregroundColor(selectedCategory.isEmpty ? .gray : .primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .sheet(isPresented: $showCategorySelection) {
                            ToDoCategorySelectionView(selectedCategory: $selectedCategory, context: viewContext)
                        }
                    }
                    Section(header: Text("Location/Address").foregroundColor(.primary)) {
                        HStack {
                            Image(systemName: "map")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .foregroundColor(.accentColor)
                                .padding(8)

                            Toggle("Item Needs Location", isOn: $needsLocation)
                                .onChange(of: needsLocation) {
                                    if !needsLocation {
                                        viewModel.selectedLocationName = Constants.emptyString
                                    } else {
                                        showMapPicker = true
                                    }
                                }
                        }

                        if needsLocation || !addressOrLocationName.isEmpty {
                            Section(
                                header:
                                    VStack(alignment: .leading, spacing: 2) {
                                        if !address.isEmpty {
                                            Text("Location: \(searchQuery)")
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text(address)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        } else if !addressOrLocationName.isEmpty {
                                            Text("Location: \(addressOrLocationName)")
                                                .font(.body)
                                                .foregroundColor(.primary)
                                        } else {
                                            Text("Location")
                                                .font(.body)
                                                .foregroundColor(.primary)
                                        }
                                    }
                                    .padding(.bottom, 2)
                            ) {
                            }
                        }
                    }
                }
                .navigationTitle(toDoItem == nil ? "New To-Do Item" : "Edit To-Do Item")
                .navigationBarItems(
                    leading: Button(Constants.cancel) { dismissSheet() }
                        .foregroundColor(.blue),
                    trailing: Button(Constants.save) { saveToDoItem() }
                        .disabled(taskName.isEmpty)
                )
                .sheet(isPresented: $showMapPicker) {
                    MapSearchView(address: $address,
                                  latitude: $latitude,
                                  longitude: $longitude,
                                  showMapPicker: $showMapPicker,
                                  needsLocation: $needsLocation)
                    .onDisappear {
                        addressOrLocationName = address
                    }
                    .onChange(of: showMapPicker) {
                        if !showMapPicker {  // When sheet is dismissed
                            if latitude == 0 && longitude == 0 {
                                needsLocation = false
                            }
                        }
                    }
                }
                .onChange(of: viewModel.selectedLocationAddress) {
                    if !viewModel.selectedLocationName.isEmpty {
                        if !viewModel.selectedLocationName.contains(",") {
                            addressOrLocationName = viewModel.selectedLocationName
                            addressOrLocationName = "\(viewModel.selectedLocationName), \(viewModel.selectedLocationAddress)"
                        } else {
                            addressOrLocationName = viewModel.selectedLocationName
                        }
                        locationSelectedFromSearch = true
                    } else {
                        addressOrLocationName = viewModel.selectedLocationAddress
                    }
                    
                    if !viewModel.selectedLocationAddress.isEmpty {
                        needsLocation = false
                    }
                }
                .background(Color(.systemBackground))
                .onChange(of: showMapPicker) {
                    if !showMapPicker {  // When sheet is dismissed
                        if latitude == 0 && longitude == 0 {
                            needsLocation = false
                        }
                    }
                }
                .onChange(of: locationSelectedFromSearch) {
                    if locationSelectedFromSearch {
                        needsLocation = false
                        locationSelectedFromSearch = false
                    }
                }
                .onChange(of: didSaveLocation) {
                    if didSaveLocation {
                        // Handle the new location (update UI, save, etc.)
                        // Optionally dismiss AddEditToDoItemView or update state
                        didSaveLocation = false // Reset for next time
                    }
                }
            }
        }
    }

    private func dismissSheet() {
        showAddTodoItem = false
        isShowingAnySheet = false
        presentationMode.wrappedValue.dismiss()
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
    
    private func saveToDoItem() {
        var newOrUpdatedToDoItem: ToDoItemEntity?
        
        Task {
            // 1. Save or update the item in Core Data via the view model
            if toDoItem == nil {
                newOrUpdatedToDoItem = toToDoItem(task: taskName,
                                                  category: selectedCategory,
                                                  addressOrLocationName: needsLocation ? addressOrLocationName : Constants.emptyString,
                                                  lastUpdate: Date(),
                                                  lastEditor: Constants.emptyString,
                                                  latitude: viewModel.latitude > 0 ? viewModel.latitude : latitude ?? 0,
                                                  longitude: viewModel.longitude > 0 ? viewModel.longitude : longitude ?? 0,
                                                  isCompleted: false,
                                                  dueDate: dueDate,
                                                  priority: priority)
                await viewModel.saveToDoItem(item: newOrUpdatedToDoItem ?? createDefaultToDoItem())
            } else if let item = toDoItem {
                // Update item properties...
                if let item = toDoItem {
                    item.task = taskName
                    item.category = selectedCategory
                    item.addressOrLocationName = needsLocation ? addressOrLocationName : Constants.emptyString
                    item.lastUpdated = Date()
                    item.lastEditor = Constants.emptyString
                    item.latitude = viewModel.latitude > 0 ? viewModel.latitude : latitude ?? 0
                    item.longitude = viewModel.longitude > 0 ? viewModel.longitude : longitude ?? 0
                    item.dueDate = dueDate
                    item.priority = priority
                    
                    newOrUpdatedToDoItem = item
                    
                    await viewModel.saveToDoItem(item: item)
                }
            }
            
            if let uid = newOrUpdatedToDoItem?.uid {
                locationManager.monitorRegionAtLocation(center: CLLocationCoordinate2D(latitude: newOrUpdatedToDoItem?.latitude ?? 0, longitude: newOrUpdatedToDoItem?.longitude ?? 0), identifier: uid)
                
                locationManager.regionIDToItemMap[uid] = newOrUpdatedToDoItem
            }

            // 2. Fetch latest data and update view model arrays
            do {
                // Fetch latest items from Core Data
                let items: [ToDoItemEntity] = try await CoreDataManager.shared().fetch(entityName: CoreDataEntities.toDoItem.stringValue)
                
                // Update view model arrays on main thread
                await MainActor.run {
                    viewModel.toDoItems = items
                    viewModel.updateGroupedToDoItems(updateExists: true)
                }

                // Update LocationManager
//                LocationManager.shared.initializeWithItems(items)
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
//                    self.locationManager.loadAndMonitorAllGeofences(from: viewContext)
//                }
            } catch {
                print("❌ Error saving To-Do item: \(error.localizedDescription)")
            }

            // 3. Dismiss the view on the main thread, after all updates
            await MainActor.run {
                // This ensures the UI only updates after the data is in sync
                dataUpdateManager.objectWillChange.send()
                presentationMode.wrappedValue.dismiss()
            }
        }
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
}

struct LocationData {
    let searchQuery: String
    let formattedAddress: String
}

//#Preview {
//    // Create a mock To-Do Item instance with sample data
//    let mockContext = PersistenceController.shared.container.viewContext
//    let mockToDoItem = ToDoItem(context: mockContext)
//    mockToDoItem.uid = UUID().uuidString
//    mockToDoItem.task = "Pick up dry cleaning"
//    mockToDoItem.category = "Errands"
//    mockToDoItem.addressOrLocationName = "City Cleaners"
//    mockToDoItem.lastUpdated = Date()
//    mockToDoItem.lastEditor = "User"
//    mockToDoItem.latitude = 37.7749
//    mockToDoItem.longitude = -122.4194
//    mockToDoItem.isCompleted = false
//    mockToDoItem.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) // Due tomorrow
//    mockToDoItem.priority = 1 // High priority
//
//    AddEditToDoItemView(
//        toDoItem: mockToDoItem,
//        showAddTodoItem: .constant(true),
//        isShowingAnySheet: .constant(true),
//        navigateToEditableList: .constant(true)
//    )
//}


