//
//  AddToDoItemView.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/5/25.
//

import SwiftUI
import CoreData
import CoreLocation
import MapKit
import UserNotifications

struct AddEditToDoItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    @EnvironmentObject private var dataUpdateManager: DataUpdateManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var viewModel: ToDoListViewModel
    @EnvironmentObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject var subscriptionsManager: SubscriptionsManager
    @EnvironmentObject var entitlementManager: EntitlementManager
    
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
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var selectedPlacemark: MKPlacemark?
    @State private var isShowingRewardedAd = false
    @State private var showHelpView = false

    @Binding var showAddTodoItem: Bool
    @Binding var isShowingAnySheet: Bool
    @Binding var navigateToEditableList: Bool
    
    let isEditingExistingItem: Bool
    
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
    
    init(toDoItem: ToDoItemEntity? = nil,
         showAddTodoItem: Binding<Bool>,
         isShowingAnySheet: Binding<Bool>,
         navigateToEditableList: Binding<Bool>,
         isEditingExistingItem: Bool) {
        self.isEditingExistingItem = isEditingExistingItem

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
                    if viewModel.isOverFreeLimit(isEditingExistingItem: isEditingExistingItem) {
                        Section {
                            FreeUserLimitView(showSubscriptionSheet: $showSubscriptionSheet,
                                              showRewardedAd: $isShowingRewardedAd)
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
                                        if !addressOrLocationName.isEmpty {
                                            Text("Location: \(addressOrLocationName)")
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text("Location: \(viewModel.mapViewFormattedAddress)")
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
                .sheet(isPresented: $isShowingRewardedAd) {
                    RewardedInterstitialContentView(
                        isPresented: $isShowingRewardedAd,
                        navigationTitle: "Task Beacon"
                    )
                }
                .navigationTitle(toDoItem == nil ? "New To-Do Item" : "Edit To-Do Item")
                .navigationBarItems(
                    leading: Button(Constants.cancel) { dismissSheet() }
                        .foregroundColor(.blue),
                    trailing: Button(Constants.save) {
                        viewModel.saveToDoItem(toDoItem: toDoItem,
                                               taskName: taskName,
                                               selectedCategory: selectedCategory,
                                               addressOrLocationName: addressOrLocationName,
                                               needsLocation: needsLocation,
                                               dueDate: dueDate,
                                               priority: priority,
                                               latitude: latitude,
                                               longitude: longitude)
                        
                        dismissSheet()
                    }
                    .disabled(taskName.isEmpty)
                )
                .sheet(isPresented: $showMapPicker) {
                    ToDoMapView(
                        cameraPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(
                                latitude: latitude ?? 0.0,
                                longitude: longitude ?? 0.0
                            ),
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )),
                        mapIsForShoppingItem: false,
                        onLocationSelected: { coordinate, name in
                            latitude = coordinate.latitude
                            longitude = coordinate.longitude
                            addressOrLocationName = name
                            showMapPicker = false
                        }
                    )
                    .environmentObject(locationManager)
                    .environmentObject(shoppingListViewModel)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showHelpView = true
                }) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showHelpView) {
            HelperView()
        }
    }

    private func dismissSheet() {
        showAddTodoItem = false
        isShowingAnySheet = false
        presentationMode.wrappedValue.dismiss()
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


