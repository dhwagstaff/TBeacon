//
//  StoreListContent.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 5/15/25.
//

import MapKit
import SwiftUI

struct StoreListContent: View {
    let stores: [MKMapItem]
    let userLocation: CLLocationCoordinate2D?
    let selectedStoreFilter: String
    let onStoreSelected: (MKMapItem) -> Void
    let locationManager: LocationManager
    
    // Computed properties to simplify the body
    private var categorizedStores: [String: [MKMapItem]] {
        let result = categorizeStores(stores)
        
        return result
    }
    
    private var filterCategory: String? {
        selectedStoreFilter == Constants.allStores ? nil : selectedStoreFilter
    }
    
    // In StoreListContent
    private var visibleCategories: [String] {
        let categories = getStoreCategories(from: categorizedStores, filterBy: filterCategory)
            .filter { category in
                // Only include categories that have stores
                guard let stores = categorizedStores[category] else { return false }
                return !stores.isEmpty
            }
        
        return categories
    }
    
    var body: some View {
        if stores.isEmpty {
            Text("No stores match your search criteria")
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(visibleCategories, id: \.self) { category in
                        categoryView(for: category)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal)
            }
            .background(Color(red: 0.95, green: 0.95, blue: 0.97)) // Light gray background
        }
    }
    
    // Helper method to create a view for each category
    @ViewBuilder
    private func categoryView(for category: String) -> some View {
        if let storesForCategory = storesForCategory(category) {
            StoreCardView(category: category,
                stores: sortStoresByDistance(storesForCategory, userLocation: userLocation),
                onStoreSelected: onStoreSelected,
                          userLocation: userLocation,
                          locationManager: locationManager)
        }
    }
    
    // Helper method to get stores for a category
    private func storesForCategory(_ category: String) -> [MKMapItem]? {
        if filterCategory == nil {
            return categorizedStores[category]
        } else if filterCategory == category {
            return categorizedStores[category]
        } else {
            return nil
        }
    }
    
    // Helper function to categorize stores
    private func categorizeStores(_ stores: [MKMapItem]) -> [String: [MKMapItem]] {
        var categorizedStores: [String: [MKMapItem]] = [:]
        
        for store in stores {
            let category = locationManager.determineStoreCategory(store)
            if categorizedStores[category] == nil {
                categorizedStores[category] = []
            }
            categorizedStores[category]?.append(store)
        }
        
        return categorizedStores
    }
    
    // Sort stores by distance
    private func sortStoresByDistance(_ stores: [MKMapItem], userLocation: CLLocationCoordinate2D?) -> [MKMapItem] {
        guard let userLocation = userLocation else {
            return stores
        }
        
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        
        return stores.sorted { storeA, storeB in
            let locationA = CLLocation(latitude: storeA.placemark.coordinate.latitude, longitude: storeA.placemark.coordinate.longitude)
            let locationB = CLLocation(latitude: storeB.placemark.coordinate.latitude, longitude: storeB.placemark.coordinate.longitude)
            
            return userCLLocation.distance(from: locationA) < userCLLocation.distance(from: locationB)
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
//#Preview {
//    StoreListContent()
//}
