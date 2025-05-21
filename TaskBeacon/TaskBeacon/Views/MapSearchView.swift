//
//  MapSearchView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/12/25.
//

import MapKit
import SwiftUI

struct MapSearchView: View {
    @Binding var address: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var showMapPicker: Bool

    @State private var searchQuery: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: MKMapItem?

    var body: some View {
        NavigationView {
            VStack {
                TextField("Search Location", text: $searchQuery, onCommit: performSearch)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                List(searchResults, id: \.self) { result in
                    Button(action: {
                        selectLocation(result)
                    }) {
                        VStack(alignment: .leading) {
                            Text(result.placemark.name ?? "Unknown Place")
                                .font(.headline)
                                .foregroundColor(.primary) // ✅ adapts to theme
                            Text(result.placemark.title ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary) // ✅ dynamic gray
                        }
                    }
                }

                if let location = selectedLocation {
                    Text("Selected: \(location.placemark.name ?? "Unknown")")
                        .padding()
                        .foregroundColor(.primary)

                    Button("Confirm Location") {
                        address = location.placemark.name ?? ""
                        latitude = location.placemark.coordinate.latitude
                        longitude = location.placemark.coordinate.longitude
                        showMapPicker = false
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .navigationTitle("Search Location")
            .navigationBarItems(trailing: Button(Constants.cancel) {
                showMapPicker = false
            })
            .background(Color(.systemBackground)) // ✅ adaptive screen bg
        }
    }

    private func performSearch() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        let search = MKLocalSearch(request: request)

        search.start { response, error in
            if let response = response {
                searchResults = response.mapItems
            } else {
                print("❌ Location search failed: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    private func selectLocation(_ location: MKMapItem) {
        selectedLocation = location
    }
}

//#Preview {
//    MapSearchView()
//}
