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
    
    @Environment(\.dismiss) private var dismiss

    @State private var cameraPosition: MapCameraPosition
    @State private var selectedItem: MKMapItem?
    @State private var searchText = Constants.emptyString
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var mapRegion: MKCoordinateRegion?

    var onLocationSelected: ((CLLocationCoordinate2D, String, String) -> Void)?
    
    init(
        cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic),
        selectedItem: MKMapItem? = nil,
        searchText: String = "",
        searchResults: [MKMapItem] = [],
        isSearching: Bool = false,
        onLocationSelected: ((CLLocationCoordinate2D, String, String) -> Void)? = nil
    ) {
        _cameraPosition = State(initialValue: cameraPosition)
        _selectedItem = State(initialValue: selectedItem)
        _searchText = State(initialValue: searchText)
        _searchResults = State(initialValue: searchResults)
        _isSearching = State(initialValue: isSearching)
        self.onLocationSelected = onLocationSelected
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with title and buttons
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .foregroundColor(.blue)
                }
                .padding(.leading)
                
                Spacer()
                
                Text("Find Location")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    if let selected = selectedItem {
                        handleLocationSelection(selected)
                        
                        onLocationSelected?(selected.placemark.coordinate, selected.name ?? "Unknown location name", formatAddress(from:selected.placemark))
                    }
                }) {
                    Text("Set Location")
                        .foregroundColor(.blue)
                }
                .padding(.trailing)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            // Search bar
            HStack {
                TextField("Search location...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing)
                }
            }
            .background(Color(.systemBackground))
            
            // Map
            Map(position: $cameraPosition, selection: $selectedItem) {
                UserAnnotation()
                
                // Show user's location
                if let userLocation = locationManager.userLocation {
                    Marker("My Location", coordinate: userLocation.coordinate)
                        .tint(.blue)
                }
                
                // Show search results
                ForEach(searchResults, id: \.self) { item in
                    Marker(item.name ?? "Location", coordinate: item.placemark.coordinate)
                        .tint(.red)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onChange(of: selectedItem) { oldValue, newValue in
                if let item = newValue {
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
            // Selected location info
            if let selected = selectedItem {
                VStack {
                    Text(selected.name ?? "Selected Location")
                        .font(.headline)
                    Text(formatAddress(from: selected.placemark))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            updateCameraPosition()
        }
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
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = [.address, .pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        isSearching = true
        
        search.start { response, error in
            isSearching = false
            
            if let error = error {
                print("❌ Search error: \(error.localizedDescription)")
                return
            }
            
            if let response = response {
                // Combine and sort results
                var allResults: [MKMapItem] = []
                
                // Add address results first
                let addressResults = response.mapItems.filter({ $0.placemark.thoroughfare != nil })
                    
                allResults.append(contentsOf: addressResults)
                
                // Add point of interest results
                let poiResults = response.mapItems.filter({ $0.name != nil })
                    
                allResults.append(contentsOf: poiResults)
                
                // Remove duplicates based on coordinate
                let uniqueResults = Array(Set(allResults.map {
                    // Convert coordinate to string for hashing
                    "\($0.placemark.coordinate.latitude),\($0.placemark.coordinate.longitude)"
                })).compactMap { coordinateString in
                    // Find the first item with this coordinate
                    allResults.first { item in
                        let itemCoord = "\(item.placemark.coordinate.latitude),\(item.placemark.coordinate.longitude)"
                        return itemCoord == coordinateString
                    }
                }
                
                searchResults = uniqueResults
                
                if let firstResult = uniqueResults.first {
                    selectLocation(firstResult)
                }
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
        handleLocationSelection(item)
    }
    
    private func handleLocationSelection(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        let name = item.name ?? "Selected Location"
        let address = formatAddress(from: item.placemark)
        
        let newRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        mapRegion = newRegion
        cameraPosition = .region(newRegion)
    }
    
    private func formatAddress(from placemark: MKPlacemark) -> String {
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }
        
        return components.joined(separator: ", ")
    }
}

//#Preview {
//    ToDoMapView()
//}
