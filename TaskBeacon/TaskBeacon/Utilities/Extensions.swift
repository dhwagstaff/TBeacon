//
//  Extensions.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/28/25.
//

import CoreData
import Foundation
import SwiftUI
import UIKit

extension NSManagedObject {

    func toToDoItem() -> ToDoItemEntity? {
        guard self.entity.name == CoreDataEntities.toDoItem.stringValue else { return nil }
                
        let todoItem = ToDoItemEntity(context: self.managedObjectContext!)
        todoItem.uid = self.value(forKey: "id") as? String ?? UUID().uuidString
        todoItem.task = self.value(forKey: "task") as? String
        todoItem.category = self.value(forKey: "category") as? String
        todoItem.addressOrLocationName = self.value(forKey: "addressOrLocationName") as? String
        todoItem.lastUpdated = self.value(forKey: "lastUpdated") as? Date
        todoItem.lastEditor = self.value(forKey: "lastEditor") as? String
        todoItem.latitude = self.value(forKey: "latitude") as? Double ?? 0.0
        todoItem.longitude = self.value(forKey: "longitude") as? Double ?? 0.0
        todoItem.isCompleted = self.value(forKey: "isCompleted") as? Bool ?? false
        todoItem.dueDate = self.value(forKey: "dueDate") as? Date
        todoItem.priority = self.value(forKey: "priority") as? Int16 ?? 0
        
        return todoItem
    }

    func toShoppingItem() -> ShoppingItemEntity? {
        guard self.entity.name == CoreDataEntities.shoppingItem.stringValue else { return nil }
                
        let shoppingItem = ShoppingItemEntity(context: self.managedObjectContext!)
        shoppingItem.uid = self.value(forKey: "id") as? String ?? UUID().uuidString
        shoppingItem.name = self.value(forKey: "name") as? String
        shoppingItem.storeName = self.value(forKey: "storeName") as? String
        shoppingItem.storeAddress = self.value(forKey: "storeAddress") as? String
        shoppingItem.category = self.value(forKey: "category") as? String
        shoppingItem.latitude = self.value(forKey: "latitude") as? Double ?? 0.0
        shoppingItem.longitude = self.value(forKey: "longitude") as? Double ?? 0.0
        shoppingItem.lastUpdated = self.value(forKey: "lastUpdated") as? Date
        shoppingItem.lastEditor = self.value(forKey: "lastEditor") as? String
        shoppingItem.isCompleted = self.value(forKey: "isCompleted") as? Bool ?? false
        shoppingItem.dateAdded = self.value(forKey: "dateAdded") as? Date
        shoppingItem.price = self.value(forKey: "price") as? Double ?? 0.0
        shoppingItem.productImage = self.value(forKey: "productImage") as? Data
        shoppingItem.gtin = self.value(forKey: "gtin") as? String
        shoppingItem.barcode = self.value(forKey: "barcode") as? String
        shoppingItem.brand = self.value(forKey: "brand") as? String
        shoppingItem.volume = self.value(forKey: "volume") as? Double ?? 0.0
        shoppingItem.unitCount = self.value(forKey: "unitCount") as? Int16 ?? 0
        shoppingItem.priority = self.value(forKey: "priority") as? Int16 ?? 0
        shoppingItem.expirationDate = self.value(forKey: "expirationDate") as? Date
        shoppingItem.emoji = self.value(forKey: "emoji") as? String
        shoppingItem.categoryEmoji = self.value(forKey: "categoryEmoji") as? String
        
        return shoppingItem
    }
}

extension Double {
    func formattedAsMiles() -> String {
        let metersToMiles = self / 1609.34
        
        if metersToMiles < 0.1 {
            return "Nearby"
        } else if metersToMiles < 1.0 {
            return String(format: "%.1f mi", metersToMiles)
        } else {
            return String(format: "%.0f mi", metersToMiles)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        
        var int: UInt64 = 0
        
        Scanner(string: hex).scanHexInt64(&int)
        
        let r, g, b, a: Double
        
        switch hex.count {
        case 6: // RGB No alpha
            (r, g, b, a) = (Double((int >> 16) & 0xFF) / 255,
            Double((int >> 8) & 0xFF) / 255,
            Double(int & 0xFF) / 255,
            1.0)
        case 8: // RGB
            (r, g, b, a) = (
                Double((int >> 24) & 0xFF) / 255,
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255,
                Double(int & 0xFF) / 255
            )
        default:
            (r, g, b, a) = (1, 1, 1, 1) // Default to white if invalid
        }
        
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
