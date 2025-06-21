//
//  ToDoMapView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/6/25.
//

import MapKit
import SwiftUI

struct ToDoMapView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var viewModel: ToDoListViewModel
    @EnvironmentObject var shoppingListViewModel: ShoppingListViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var cameraPosition: MapCameraPosition
    @State private var selectedItem: MKMapItem?
    @State private var searchText = Constants.emptyString
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var mapRegion: MKCoordinateRegion?
    @State private var showStoreSelectionSheet = false
    @State private var selectedStoreFilter: String = Constants.emptyString
    @State private var storeName: String = Constants.emptyString
    @State private var storeAddress: String = Constants.emptyString
    @State private var selectedStore: MKMapItem?
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var isPreferred: Bool = false

    var mapIsForShoppingItem: Bool
    var onLocationSelected: ((CLLocationCoordinate2D, String) -> Void)?
    
    init(cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic),
         selectedItem: MKMapItem? = nil,
         searchText: String = Constants.emptyString,
         searchResults: [MKMapItem] = [],
         isSearching: Bool = false,
         mapIsForShoppingItem: Bool,
         onLocationSelected: ((CLLocationCoordinate2D, String) -> Void)? = nil
    ) {
        _cameraPosition = State(initialValue: cameraPosition)
        _selectedItem = State(initialValue: selectedItem)
        _searchText = State(initialValue: searchText)
        _searchResults = State(initialValue: searchResults)
        _isSearching = State(initialValue: isSearching)
        
        self.mapIsForShoppingItem = mapIsForShoppingItem
        self.onLocationSelected = onLocationSelected
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Find Location")
                .font(.title)

            // The top HStack now only contains the Cancel button.
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .foregroundColor(.blue)
                }
                .padding(.leading)
                
                Spacer()
                
                if mapIsForShoppingItem {
                    Button("Show All Stores") {
                        showStoreSelectionSheet = true
                    }
                    .padding(.trailing)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            // The search bar remains the same.
            HStack {
                TextField("Search for a business or address...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        selectedItem = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing)
                }
            }
            .background(Color(.systemBackground))
            
            // The Map view itself remains the same.
            Map(position: $cameraPosition, selection: $selectedItem) {
                UserAnnotation()
                
                if let userLocation = locationManager.userLocation {
                    Marker("My Location", coordinate: userLocation.coordinate)
                        .tint(.blue)
                }
                
                ForEach(searchResults) { item in
                    Marker(item.name ?? "Location", coordinate: item.placemark.coordinate)
                        .tint(.red)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onChange(of: selectedItem) {
                if let item = selectedItem {
                    let coordinate = item.placemark.coordinate
                    let newRegion = MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    )
                    mapRegion = newRegion
                    cameraPosition = .region(newRegion)
                    handleLocationSelection(item)
                }
            }

            // This is the new bottom section. It only appears when a location is selected.
            if let selected = selectedItem {
                VStack(spacing: 15) {
                    // Display the selected location's details
                    // The "Use Location" button has been moved here and styled.
                    if let selected = selectedItem {
                        VStack(spacing: 15) {
                            // Display the selected location's details
                            VStack {
                                Text(selected.name ?? "Selected Location")
                                    .font(.headline)
                                Text(addressString(for: selected.placemark))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            // The primary "Use This Location" button
                            Button(action: {
                                handleLocationSelection(selected)
                                
                                let address = formatAddress(from: selected.placemark)
                                viewModel.lookupBusinessName(from: address) { businessName in
                                    onLocationSelected?(selected.placemark.coordinate,
                                                        returnLocationName(selectedPlacemarkName: selected.name ?? "Unknown location name"))
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        dismiss()
                                    }
                                }
                            }) {
                                Text("Use This Location")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentColor)
                                    .cornerRadius(12)
                            }
                            
                            // The new "Back to Results" button.
                            Button(action: {
                                // Clearing the selection is all that's needed to
                                // hide this view and show the list again.
                                self.selectedItem = nil
                            }) {
                                Text("Back to Search Results")
                                    .fontWeight(.medium)
                            }
                            .padding(.top, 5)

                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .transition(.move(edge: .bottom)) // Adds a nice slide-in animation
            }
            
            // The search results list remains the same.
            if !searchResults.isEmpty && selectedItem == nil {
                List(searchResults) { item in
                    VStack(alignment: .leading) {
                        Text(item.name ?? "Result")
                            .font(.headline)
                        Text(addressString(for: item.placemark))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectLocation(item)
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(.top, 20)
        .animation(.default, value: selectedItem) // Animates the appearance of the bottom section
        .onAppear {
            updateCameraPosition()
        }
        .sheet(isPresented: $showStoreSelectionSheet, onDismiss: {
            // When the sheet is dismissed, check if a store was selected.
            if let store = selectedStore, let lat = latitude, let long = longitude {
                let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: long))
                let mapItem = MKMapItem(placemark: placemark)
                mapItem.name = store.name

                // Update the map to show this selection
                self.selectedItem = mapItem
                handleLocationChange(to: mapItem)
            }
        }) {
            UnifiedStoreSelectionView(isPresented: $showStoreSelectionSheet,
                                      selectedStoreFilter: $selectedStoreFilter,
                                      storeName: $storeName,
                                      storeAddress: $storeAddress,
                                      selectedStore: $selectedStore,
                                      latitude: $latitude,
                                      longitude: $longitude,
                                      isPreferred: $isPreferred
            )
            .environmentObject(shoppingListViewModel)
            .environmentObject(locationManager)
        }
    }
    
    private func useLocation(_ selected: MKMapItem) {
        handleLocationSelection(selected)
        let address = formatAddress(from: selected.placemark)
        viewModel.lookupBusinessName(from: address) { businessName in
            onLocationSelected?(selected.placemark.coordinate,
                                returnLocationName(selectedPlacemarkName: selected.name ?? "Unknown location name"))
        }
    }
    
    private func handleLocationChange(to item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        let newRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        mapRegion = newRegion
        withAnimation {
            cameraPosition = .region(newRegion)
        }
        handleLocationSelection(item)
    }
    
    func returnLocationName(selectedPlacemarkName: String) -> String {
        if viewModel.mapViewFormattedAddress.contains(selectedPlacemarkName) {
            return viewModel.businessName
        }
        
        return selectedPlacemarkName
    }
    
    private func updateCameraPosition() {
        if let userLocation = locationManager.userLocation {
            cameraPosition = .region(MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        selectedItem = nil
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        // This is the key change:
        // 1. We specify we're looking for Points of Interest to get businesses, not just places.
        request.resultTypes = .pointOfInterest
        
        // 2. We provide the user's location as a HINT. This helps rank local results
        // higher without filtering out more distant ones. This makes it behave
        // more like the native Maps app.
        if let userLocation = locationManager.userLocation {
            request.region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 50000, longitudinalMeters: 50000) // 50km (31 mile) radius hint
        }
        
        isSearching = true
        
        Task {
            do {
                let response = try await MKLocalSearch(request: request).start()
                await MainActor.run {
                    var uniqueResults: [MKMapItem] = []
                    var seenIdentifiers = Set<String>()

                    for item in response.mapItems {
                        let identifier = item.id // Use the unique ID from our extension.
                        if !seenIdentifiers.contains(identifier) {
                            uniqueResults.append(item)
                            seenIdentifiers.insert(identifier)
                        }
                    }
                    
                    self.searchResults = uniqueResults
                    
                    if self.searchResults.count == 1, let firstResult = self.searchResults.first {
                        self.selectLocation(firstResult)
                    }
                }
            } catch {
                print("Search error: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                isSearching = false
            }
        }
    }
    
    private func selectLocation(_ item: MKMapItem) {
        selectedItem = item
        let coordinate = item.placemark.coordinate
        let newRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        mapRegion = newRegion
        cameraPosition = .region(newRegion)
    }
    
    private func handleLocationSelection(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        
        let newRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        mapRegion = newRegion
        cameraPosition = .region(newRegion)
    }
    
    private func addressString(for placemark: MKPlacemark) -> String {
        var addressParts: [String] = []
        if let number = placemark.subThoroughfare, let street = placemark.thoroughfare {
            addressParts.append("\(number) \(street)")
        } else if let street = placemark.thoroughfare {
            addressParts.append(street)
        }

        if let city = placemark.locality {
            addressParts.append(city)
        }
        if let state = placemark.administrativeArea {
            addressParts.append(state)
        }
        
        return addressParts.joined(separator: ", ")
    }
    
    private func formatAddress(from placemark: MKPlacemark) -> String {
        // This function has a side effect of setting a viewModel property.
        // It's kept for the 'Use Location' button's logic.
        if let addressNumber = placemark.subThoroughfare,
           let street = placemark.thoroughfare,
           let city = placemark.locality,
           let state = placemark.administrativeArea {
            let basicAddress = "\(addressNumber) \(street), \(city), \(state)"
            viewModel.mapViewFormattedAddress = basicAddress
            return basicAddress
        }
        
        return "Address not available"
    }
}

//#Preview {
//    ToDoMapView()
//}

