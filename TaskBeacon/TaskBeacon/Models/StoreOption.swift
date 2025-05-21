//
//  StoreOption.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/8/25.
//

import Foundation
import MapKit

struct StorePriceResponse: Codable {
    let stores: [StoreOption]
}

struct StoreOption: Identifiable, Codable, Hashable {
    // ID computed property from the "master" struct
    var id: String { storeID }
    
    // Common properties between both structs
    let storeID: String
    let name: String
    var address: String
    var category: String
    
    // Properties from the master struct
    var price: Double = 0.0
    var distance: Double? // Distance in meters
    var drivingDistance: Double? // Driving distance in meters (if available)
    var drivingTime: TimeInterval? // Estimated driving time in seconds (if available)
    
    // From the first struct - needed for MKMapItem access
    var mapItem: MKMapItem
    
    // Format distance for display
//    var formattedDistance: String {
//        guard let dist = drivingDistance ?? distance else {
//            return "Unknown distance"
//        }
//        
//        // Convert from meters to miles
//        let distanceInMiles = dist / 1609.34
//        
//        if distanceInMiles < 0.1 {
//            return "nearby"
//        } else if distanceInMiles < 10 {
//            return String(format: "%.1f mi", distanceInMiles)
//        } else {
//            return String(format: "%.0f mi", distanceInMiles)
//        }
//    }
    
    // Format driving time for display
//    var formattedDrivingTime: String? {
//        guard let time = drivingTime else { return nil }
//        
//        let minutes = Int(time / 60)
//        if minutes < 1 {
//            return "< 1 min drive"
//        } else if minutes == 1 {
//            return "1 min drive"
//        } else if minutes < 60 {
//            return "\(minutes) min drive"
//        } else {
//            let hours = minutes / 60
//            let remainingMinutes = minutes % 60
//            if remainingMinutes == 0 {
//                return "\(hours) hr drive"
//            } else {
//                return "\(hours) hr \(remainingMinutes) min drive"
//            }
//        }
//    }
    
    // Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(storeID)
    }
    
    static func == (lhs: StoreOption, rhs: StoreOption) -> Bool {
        return lhs.storeID == rhs.storeID
    }
    
    // Handle MKMapItem for Codable
    enum CodingKeys: String, CodingKey {
        case storeID, name, price, distance, drivingDistance, drivingTime, address, category
    }
    
    init(storeID: String, name: String, price: Double = 0.0, distance: Double? = nil,
         drivingDistance: Double? = nil, drivingTime: TimeInterval? = nil,
         address: String, category: String, mapItem: MKMapItem) {
        self.storeID = storeID
        self.name = name
        self.price = price
        self.distance = distance
        self.drivingDistance = drivingDistance
        self.drivingTime = drivingTime
        self.address = address
        self.category = category
        self.mapItem = mapItem
    }
    
    // Custom initializer for decoding (needed because mapItem isn't Codable)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        storeID = try container.decode(String.self, forKey: .storeID)
        name = try container.decode(String.self, forKey: .name)
        price = try container.decode(Double.self, forKey: .price)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        drivingDistance = try container.decodeIfPresent(Double.self, forKey: .drivingDistance)
        drivingTime = try container.decodeIfPresent(TimeInterval.self, forKey: .drivingTime)
        address = try container.decode(String.self, forKey: .address)
        category = try container.decode(String.self, forKey: .category)
        
        // Create a placeholder mapItem since we can't decode it
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let placemark = MKPlacemark(coordinate: coordinate)
        mapItem = MKMapItem(placemark: placemark)
    }
    
    // Custom encoding (to handle non-Codable mapItem)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(storeID, forKey: .storeID)
        try container.encode(name, forKey: .name)
        try container.encode(price, forKey: .price)
        try container.encodeIfPresent(distance, forKey: .distance)
        try container.encodeIfPresent(drivingDistance, forKey: .drivingDistance)
        try container.encodeIfPresent(drivingTime, forKey: .drivingTime)
        try container.encode(address, forKey: .address)
        try container.encode(category, forKey: .category)
        // mapItem is excluded from encoding
    }
}
