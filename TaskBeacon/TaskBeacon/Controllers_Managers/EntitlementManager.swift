//
//  EntitlementManager.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/1/25.
//

import SwiftUI

class EntitlementManager: ObservableObject {
    @AppStorage("extraToDoOrShoppingItems", store: userDefaults) var extraToDoSlots: Int = 0
    @AppStorage("isAdFree", store: userDefaults) var isAdFree: Bool = false
    @AppStorage("hasChosenFreeVersion", store: userDefaults) var hasChosenFreeVersion: Bool = false

    static let userDefaults = UserDefaults(suiteName: "group.pocketmeapps.taskbeacon")!
    
    static let shared = EntitlementManager()

    @Published var isPremiumUser: Bool {
        didSet {
            Self.userDefaults.set(isPremiumUser, forKey: "isPremiumUser")
            objectWillChange.send() // 🔹 Ensure UI refresh
        }
    }

    init() {
        // Load value from UserDefaults at startup
        _isPremiumUser = Published(initialValue: Self.userDefaults.bool(forKey: "isPremiumUser"))
    }
}
