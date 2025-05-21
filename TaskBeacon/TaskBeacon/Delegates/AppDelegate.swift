//
//  AppDelegate.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/8/25.
//

import CoreData
import Foundation
import GoogleMobileAds
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    private var hasInitializedLocationManager = false

    var window: UIWindow?
    
    var adManager = AdManager() // ✅ Create an instance
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            QuickActionsManager.shared.handleQuickActionItem(shortcutItem)
        }

        let sceneConfiguration = UISceneConfiguration(name: "Custom Configuration", sessionRole: connectingSceneSession.role)
        sceneConfiguration.delegateClass = CustomSceneDelegate.self

        return sceneConfiguration
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        
        print("📌 Quick Action Triggered: \(shortcutItem.type)") // ✅ Debug log
                
        // handle quick actions
        NotificationCenter.default.post(name: .quickActionTriggered, object: shortcutItem.type)
        completionHandler(true)
    }
    
    private func clearNotifications(_ application: UIApplication) {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().setBadgeCount(0)
        print("🧹 Cleared all notifications and reset badge count.")
    }
    
    // Fetch items and initialize LocationManager
    private func initializeLocationManager() {
        print("🛎️ Fetching data for LocationManager initialization...")
        let context = PersistenceController.shared.container.viewContext
        var items: [NSManagedObject] = []
        
        let todoRequest = NSFetchRequest<ToDoItemEntity>(entityName: CoreDataEntities.toDoItem.stringValue)
        let shoppingRequest = NSFetchRequest<ShoppingItemEntity>(entityName: CoreDataEntities.shoppingItem.stringValue)
        
        do {
            let todos = try context.fetch(todoRequest)
            let shoppingItems = try context.fetch(shoppingRequest)
            
            items.append(contentsOf: todos)
            items.append(contentsOf: shoppingItems)
            
            print("✅ Fetched \(items.count) items for location monitoring.")
            LocationManager.shared.initializeWithItems(items, context: context)
        } catch {
            print("❌ Error fetching items: \(error)")
        }
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if !hasInitializedLocationManager {
            initializeLocationManager()
            hasInitializedLocationManager = true
        }

        clearNotifications(application)
        initializeLocationManager()
        
        print("🚀 Initializing Google Mobile Ads SDK...")
        
        // Start Google Mobile Ads SDK with a slight delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            MobileAds.shared.start(completionHandler: nil)
        }

        // Request notification permission
        NotificationDelegate.shared.requestNotificationPermission()

        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if let lastRefresh = UserDefaults.standard.object(forKey: "lastGeofenceRefresh") as? Date,
           Date().timeIntervalSince(lastRefresh) < 300 { // 5 minutes
            return
        }
        
        print("📲 App became active. Refreshing geofences.")
        
        let context = PersistenceController.shared.container.viewContext
        var items: [NSManagedObject] = []
        
        let todoRequest = NSFetchRequest<ToDoItemEntity>(entityName: CoreDataEntities.toDoItem.stringValue)
        let shoppingRequest = NSFetchRequest<ShoppingItemEntity>(entityName: CoreDataEntities.shoppingItem.stringValue)
        
        do {
            let todos = try context.fetch(todoRequest)
            let shoppingItems = try context.fetch(shoppingRequest)
            
            items.append(contentsOf: todos)
            items.append(contentsOf: shoppingItems)
            
            LocationManager.shared.initializeWithItems(items, context: context)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                LocationManager.shared.loadAndMonitorAllGeofences(from: context)
            }
        } catch {
            print("❌ Error fetching items: \(error)")
        }
        
        // Rest of existing refresh code...
        UserDefaults.standard.set(Date(), forKey: "lastGeofenceRefresh")
    }
}

extension Notification.Name {
    static let quickActionTriggered = Notification.Name("quickActionTriggered")
}

class CustomSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        QuickActionsManager.shared.handleQuickActionItem(shortcutItem)
    }
}
