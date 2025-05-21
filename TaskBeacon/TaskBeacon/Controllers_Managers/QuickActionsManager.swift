//
//  QuickActionsManager.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 2/22/25.
//

import SwiftUI

class QuickActionsManager: ObservableObject {
    static let shared = QuickActionsManager()
    
    @Published var quickAction: QuickAction? = nil
    
    func handleQuickActionItem(_ item: UIApplicationShortcutItem) {
        print("item :::> \(item)")
                
        if item.type == "com.pocketmeapps.TaskBeacon.addtodo" {
            quickAction = .isAddingToDoItem
        } else if item.type == "com.pocketmeapps.TaskBeacon.addshopping" {
            quickAction = .isAddingShoppingItem
        } else if item.type == "com.pocketmeapps.TaskBeacon.upcomingtodos" {
            quickAction = .isUpcomingToDoItem
        }
    }
}

enum QuickAction: Hashable {
    case isAddingToDoItem
    case isAddingShoppingItem
    case isUpcomingToDoItem
}
