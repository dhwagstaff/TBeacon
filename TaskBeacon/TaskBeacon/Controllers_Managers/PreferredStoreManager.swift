//
//  PreferredStoreManager.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/24/25.
//

import Foundation
import SwiftUI

class PreferredStoreManager: ObservableObject {
    @AppStorage("preferredStoreName") var name: String = ""
    @AppStorage("preferredStoreAddress") var address: String = ""
    @AppStorage("preferredStoreLatitude") var latitude: Double = 0.0
    @AppStorage("preferredStoreLongitude") var longitude: Double = 0.0
    
    func setPreferredStore(name: String, address: String, latitude: Double, longitude: Double) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }
    
    func clearPreferredStore() {
        name = ""
        address = ""
        latitude = 0.0
        longitude = 0.0
    }
    
    var hasPreferredStore: Bool {
        return !name.isEmpty
    }
}
