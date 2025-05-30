//
//  MapSearchView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/12/25.
//

import MapKit
import SwiftUI

struct MapSearchView: View {
    @StateObject private var locationManager = LocationManager.shared
    
    @Binding var address: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var showMapPicker: Bool
    @Binding var needsLocation: Bool

    @State private var searchQuery: String = Constants.emptyString
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var isSearching = false
    
    init(address: Binding<String>,
         latitude: Binding<Double?>,
         longitude: Binding<Double?>,
         showMapPicker: Binding<Bool>,
         needsLocation: Binding<Bool>) {
        self._address = address
        self._latitude = latitude
        self._longitude = longitude
        self._showMapPicker = showMapPicker
        self._needsLocation = needsLocation
        
        // Initialize selectedLocation with passed in coordinates if they exist
        if let lat = latitude.wrappedValue, let lon = longitude.wrappedValue {
            _selectedLocation = State(initialValue: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 5) {
                TextField("Search Location", text: $searchQuery)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .onSubmit {
                        searchLocation()
                    }
                
                MapView(latitude: $latitude, longitude: $longitude, selectedLocation: $selectedLocation)
                    .onAppear {
                        if let userLocation = locationManager.userLocation?.coordinate {
                            selectedLocation = userLocation
                            latitude = userLocation.latitude
                            longitude = userLocation.longitude
                        }
                    }
                    .edgesIgnoringSafeArea([.leading, .trailing])
                
                if !searchResults.isEmpty {
                    Button("Set Location") {
                        address = formatAddress(from: searchResults.first?.placemark)
                        latitude = searchResults.first?.placemark.coordinate.latitude
                        longitude = searchResults.first?.placemark.coordinate.longitude
                        showMapPicker = false
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .onAppear {
                if let userLocation = locationManager.userLocation?.coordinate {
                    selectedLocation = userLocation
                    latitude = userLocation.latitude
                    longitude = userLocation.longitude
                }
            }
            .navigationTitle("Search Location")
            .navigationBarItems(trailing: Button(Constants.cancel) {
                needsLocation = false
                showMapPicker = false
            })
            .background(Color(.systemBackground))
        }
    }
    
    private func formatAddress(from placemark: MKPlacemark?) -> String {
        guard let placemark else { return Constants.emptyString }

        return (placemark.name ?? Constants.emptyString) + ", \((placemark.locality ?? Constants.emptyString))"
    }
    
    private func searchLocation() {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        request.region = MKCoordinateRegion(
            center: selectedLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
            latitudinalMeters: 10000,
            longitudinalMeters: 10000
        )
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            
            if let error = error {
                print("Search error: \(error.localizedDescription)")
                return
            }
            
            if let response = response {
                searchResults = response.mapItems
                
                // If we have results, move the map to the first result and set a marker
                if let firstResult = response.mapItems.first {
                    let coordinate = firstResult.placemark.coordinate
                    selectedLocation = coordinate
                    
                    // Update the map view's latitude and longitude
                    latitude = coordinate.latitude
                    longitude = coordinate.longitude
                }
            }
        }
    }
}

//#Preview {
//    MapSearchView()
//}
