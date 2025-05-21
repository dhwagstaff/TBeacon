//
//  DataUpdateManager.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 2/13/25.
//

import Foundation
import Combine

class DataUpdateManager: ObservableObject {
    
    static let shared = DataUpdateManager()
    
    @Published var needsRefresh = false
    
    func triggerUpdate() {
        DispatchQueue.main.async {
            self.needsRefresh.toggle() // ✅ Forces SwiftUI to refresh
        }
    }
}
