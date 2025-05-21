//
//  MapViewWrapper.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 5/2/25.
//

import Foundation
import MapKit
import SwiftUI
import UIKit

struct MapViewWrapper: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: ToDoListViewModel

    @Binding var latitude: Double
    @Binding var longitude: Double
    @Binding var storeName: String
    @Binding var storeAddress: String
    
    // Add a property to determine if this is for a to-do item
    var isForToDoItem: Bool = false
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let storyboard = UIStoryboard(name: "Map", bundle: nil)
        guard let viewController = storyboard.instantiateViewController(identifier: "MapViewController") as? MapViewController else {
            fatalError("Could not instantiate MapViewController from storyboard")
        }
        
        // Set the viewModel
        viewController.viewModel = viewModel
        
        viewController.onLocationSelected = { coordinate in
            latitude = coordinate.latitude
            longitude = coordinate.longitude
            
            // Get address for selected location
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let placemark = placemarks?.first {
                    print("📍 MapViewWrapper: Got placemark - \(placemark.name ?? "Unknown")")
                    viewModel.selectedLocationAddress = formatAddress(from: placemark)
                    
                    print("📍 MapViewWrapper: Set location name to \(viewModel.selectedLocationName)")
                    print("📍 MapViewWrapper: Set location address to \(viewModel.selectedLocationAddress)")
                } else {
                    print("❌ MapViewWrapper: Failed to get placemark")
                }
                
                // Only dismiss if this is not for a to-do item
                if !isForToDoItem {
                    print("📍 MapViewWrapper: Dismissing (not for to-do item)")
                    presentationMode.wrappedValue.dismiss()
                } else {
                    print("📍 MapViewWrapper: Not dismissing (is for to-do item)")
                }
            }
        }
        
        // Create a navigation controller with the map view controller as its root
        let navigationController = UINavigationController(rootViewController: viewController)
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No updates needed
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        // Add the street address first
        if let thoroughfare = placemark.thoroughfare {
            if let subThoroughfare = placemark.subThoroughfare {
                components.append("\(subThoroughfare) \(thoroughfare)")
            } else {
                components.append(thoroughfare)
            }
        }
        
        // Add city
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        // Add state
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        // Add zip code
        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }
        
        return components.joined(separator: ", ")
    }
}
