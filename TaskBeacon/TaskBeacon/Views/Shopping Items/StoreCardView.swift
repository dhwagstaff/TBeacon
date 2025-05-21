//
//  StoreCardView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 5/15/25.
//

import MapKit
import SwiftUI

struct StoreCardView: View {
    let category: String
    let stores: [MKMapItem]
    let onStoreSelected: (MKMapItem) -> Void
    let userLocation: CLLocationCoordinate2D?
    let locationManager: LocationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header
            HStack(spacing: 8) {
                Image(systemName: getCategoryIcon(for: category))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 32, height: 32)
                    )
                
                Text(category)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Divider
            Rectangle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(height: 2)
                .padding(.horizontal)
            
            // Store items
            ForEach(stores, id: \.self) { store in
                Button(action: {
                    onStoreSelected(store)
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.name ?? "Unknown Store")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let address = StoreCardView.getFormattedAddress(from: store) {
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        if let userLocation = userLocation {
                            let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                            let storeCLLocation = CLLocation(latitude: store.placemark.coordinate.latitude,
                                                            longitude: store.placemark.coordinate.longitude)
                            let distance = userCLLocation.distance(from: storeCLLocation)
                            
                            Text(distance.formattedAsMiles())
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                if store != stores.last {
                    Divider()
                        .padding(.leading)
                }
            }
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // Helper function to get a formatted address
    static func getFormattedAddress(from mapItem: MKMapItem) -> String? {
        if let title = mapItem.placemark.title, !title.isEmpty {
            return title
        }
        
        var addressParts = [String]()
        
        if let street = mapItem.placemark.thoroughfare {
            addressParts.append(street)
        }
        
        if let city = mapItem.placemark.locality {
            addressParts.append(city)
        }
        
        if let state = mapItem.placemark.administrativeArea {
            addressParts.append(state)
        }
        
        return addressParts.isEmpty ? "No address available" : addressParts.joined(separator: ", ")
    }
}

//#Preview {
//    StoreCardView()
//}
