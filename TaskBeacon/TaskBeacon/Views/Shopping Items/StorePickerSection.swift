//
//  StorePickerSection.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 5/15/25.
//

import MapKit
import SwiftUI

struct StorePickerSection: View {
    @Binding var storeName: String
    @Binding var storeAddress: String
    @Binding var showStoreDetails: Bool
    @Binding var showStoreSelection: Bool
    @Binding var selectedStore: MKMapItem?
    @Binding var isEditingText: Bool
    
    var locationManager: LocationManager
    
    var body: some View {
        RoundedSectionBackground(title: "Store", iconName: "storefront") {
            VStack(spacing: 8) {
                Button("Select a Store") {
                    // Explicitly dismiss keyboard
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    
                    isEditingText = false
                    
                    locationManager.objectWillChange.send()
                    
                    // Add a slightly longer delay to ensure the keyboard is fully dismissed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showStoreSelection = true
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                if !storeName.isEmpty && !storeAddress.isEmpty && showStoreDetails {
                    Divider()
                        .padding(.vertical, 8)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "storefront.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundColor(.accentColor)
                            .padding(8)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(storeName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            // Show store type if available
                            if let store = selectedStore {
                                StoreTypeLabel(store: store, locationManager: locationManager)
                            }
                            
                            Text(storeAddress)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
        }
        .transition(.opacity)
        .animation(.easeInOut, value: true)
    }
}

private struct StoreTypeLabel: View {
    let store: MKMapItem
    let locationManager: LocationManager
    
    var body: some View {
        let storeType = locationManager.determineStoreCategory(store)
        if !storeType.isEmpty {
            Text(storeType)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(Color.accentColor.opacity(0.8))
                .cornerRadius(12)
        }
    }
}

//#Preview {
//    StorePickerSection()
//}
